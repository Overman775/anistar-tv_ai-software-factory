"""Runner failures and platform results must remain visible to CI."""

import json
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from e2e_report import write_aggregate, write_host_report, write_run_report


class E2eReportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)

    def report(self, directory, platform='tv', exit_code=0, phase='complete'):
        write_run_report(
            directory, platform=platform, mode='fixtures', seed=42,
            device='emulator-5554', avd='existing_avd', exit_code=exit_code,
            phase=phase, started_at='2026-10-11T00:00:00+00:00',
        )

    def host_report(self, directory, exit_code=0, phase='flutter-tests'):
        return write_host_report(
            directory, suite_name='unit', scope='full', selector=[], seed=42,
            exit_code=exit_code, phase=phase, started_at='2026-10-11T00:00:00+00:00',
        )

    def test_preflight_failure_without_flutter_events_is_a_junit_error(self):
        self.report(self.directory, exit_code=1, phase='preflight')
        suite = ET.parse(self.directory / 'junit.xml').getroot()
        self.assertEqual(suite.attrib['errors'], '1')
        self.assertEqual(suite.find('testcase').attrib['name'], 'preflight')
        summary = json.loads((self.directory / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'failed')
        self.assertEqual(summary['avd'], 'existing_avd')

    def test_flutter_events_preserve_success_failure_skipped_and_unfinished_tests(self):
        events = [
            {'type': 'testStart', 'test': {'id': 0, 'name': 'loading', 'hidden': True}},
            {'type': 'testDone', 'testID': 0, 'result': 'success', 'hidden': True},
            {'type': 'testStart', 'test': {'id': 1, 'name': 'touch'}, 'time': 100},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'time': 300},
            {'type': 'testStart', 'test': {'id': 2, 'name': 'playback'}},
            {'type': 'error', 'testID': 2, 'error': 'expectation failed', 'stackTrace': 'test.dart:12'},
            {'type': 'testDone', 'testID': 2, 'result': 'failure'},
            {'type': 'testStart', 'test': {'id': 3, 'name': 'optional'}},
            {'type': 'testDone', 'testID': 3, 'result': 'success', 'skipped': True},
            {'type': 'testStart', 'test': {'id': 4, 'name': 'interrupted'}},
            {'type': 'done', 'success': True},
        ]
        (self.directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))
        self.report(self.directory, exit_code=1, phase='flutter-tests')
        suite = ET.parse(self.directory / 'junit.xml').getroot()
        self.assertEqual(suite.attrib['tests'], '4')
        self.assertEqual(suite.attrib['failures'], '1')
        self.assertEqual(suite.attrib['errors'], '1')
        self.assertEqual(suite.attrib['skipped'], '1')
        self.assertEqual(suite.find('testcase').attrib['time'], '0.2')
        self.assertIn('test.dart:12', suite.find('testcase/failure').text)

    def test_aggregate_keeps_failed_tv_and_passed_mobile_results(self):
        tv = self.directory / 'tv'
        mobile = self.directory / 'mobile'
        self.report(tv, exit_code=1, phase='preflight')
        mobile.mkdir()
        (mobile / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'touch'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': False},
            {'type': 'done', 'success': True},
        ]))
        self.report(mobile, platform='mobile')
        write_aggregate(self.directory, [tv, mobile])
        summary = json.loads((self.directory / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'failed')
        self.assertEqual([item['exit_code'] for item in summary['runs']], [1, 0])
        suites = ET.parse(self.directory / 'junit.xml').getroot()
        self.assertEqual(len(suites), 2)
        self.assertEqual(suites.attrib['errors'], '1')

    def test_zero_native_cases_cannot_report_success(self):
        for events in ([], [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'loading'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': True},
            {'type': 'done', 'success': True},
        ], [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'skipped'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'skipped': True},
            {'type': 'done', 'success': True},
        ]):
            with self.subTest(events=events):
                (self.directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))
                self.report(self.directory)
                summary = json.loads((self.directory / 'summary.json').read_text())
                self.assertEqual(summary['status'], 'failed')
                self.assertEqual(summary['exit_code'], 1)
                self.assertEqual(summary['phase'], 'report-validation')
                self.assertEqual(summary['native_tests'], 0)

    def test_successful_process_with_unfinished_test_is_failed(self):
        (self.directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'touch'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': False},
            {'type': 'testStart', 'test': {'id': 2, 'name': 'interrupted'}},
            {'type': 'done', 'success': True},
        ]))
        self.report(self.directory)
        summary = json.loads((self.directory / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'failed')
        self.assertEqual(summary['exit_code'], 1)
        self.assertEqual(summary['errors'], 1)

    def test_host_report_rejects_corrupt_events_and_preserves_runner_exit_code(self):
        (self.directory / 'flutter-events.jsonl').write_text('not json\n')
        corrupt = write_host_report(
            self.directory, suite_name='unit', scope='filtered', selector=['--name', '^one$'],
            seed=42, exit_code=0, phase='flutter-tests', started_at='2026-10-11T00:00:00+00:00',
        )
        self.assertEqual(corrupt['exit_code'], 1)
        self.assertEqual(corrupt['phase'], 'report-validation')
        self.assertEqual(corrupt['completed_tests'], [])
        self.assertEqual(corrupt['selector'], ['--name', '^one$'])

        failed = write_host_report(
            self.directory, suite_name='unit', scope='full', selector=[],
            seed=42, exit_code=17, phase='flutter-tests', started_at='2026-10-11T00:00:00+00:00',
        )
        self.assertEqual(failed['exit_code'], 17)
        self.assertEqual(failed['phase'], 'flutter-tests')

    def test_stage_report_records_a_failed_stage_without_becoming_the_stage_exit(self):
        directory = self.directory / 'stage'
        result = subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name('e2e_report.py')),
                'stage',
                '--directory',
                str(directory),
                '--suite',
                'format-check',
                '--seed',
                '42',
                '--exit-code',
                '17',
                '--phase',
                'format-check',
                '--started-at',
                '2026-10-11T00:00:00+00:00',
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        summary = json.loads((directory / 'summary.json').read_text())
        self.assertEqual(summary['exit_code'], 17)
        self.assertEqual(summary['status'], 'failed')
        event = json.loads((directory / 'events.jsonl').read_text())
        self.assertEqual(event['exit_code'], 17)

    def test_host_report_fails_a_late_flutter_error_after_test_done(self):
        events = [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'selected'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success'},
            {'type': 'error', 'testID': 1, 'error': 'late failure', 'stackTrace': 'test.dart:99'},
            {'type': 'done', 'success': True},
        ]
        (self.directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))

        summary = write_host_report(
            self.directory, suite_name='goldens', scope='filtered', selector=['--name', '^selected$'],
            seed=42, exit_code=0, phase='flutter-tests', started_at='2026-10-11T00:00:00+00:00',
        )

        self.assertEqual(summary['exit_code'], 1)
        self.assertEqual(summary['phase'], 'report-validation')
        self.assertEqual(summary['completed_tests'], ['selected'])
        suite = ET.parse(self.directory / 'junit.xml').getroot()
        self.assertEqual(suite.attrib['errors'], '1')
        self.assertIn('late failure', suite.find('testcase/error').text)

    def test_hidden_setup_late_error_is_visible_in_host_and_native_reports(self):
        events = [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'hidden setup', 'hidden': True}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': True},
            {'type': 'testStart', 'test': {'id': 2, 'name': 'hidden successful fixture', 'hidden': True}},
            {'type': 'testDone', 'testID': 2, 'result': 'success', 'hidden': True},
            {'type': 'testStart', 'test': {'id': 3, 'name': 'visible test'}},
            {'type': 'testDone', 'testID': 3, 'result': 'success'},
            {'type': 'error', 'testID': 1, 'error': 'late setup failure', 'stackTrace': 'setup.dart:77'},
            {'type': 'done', 'success': True},
        ]
        for report_type in ('host', 'native'):
            with self.subTest(report_type=report_type):
                directory = self.directory / report_type
                directory.mkdir()
                (directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))
                summary = self.host_report(directory) if report_type == 'host' else self.report(directory)
                if summary is None:
                    summary = json.loads((directory / 'summary.json').read_text())

                self.assertEqual(summary['exit_code'], 1)
                self.assertEqual(summary['phase'], 'report-validation')
                self.assertEqual(summary['completed_tests'], ['hidden setup', 'visible test'])
                self.assertNotIn('hidden successful fixture', summary['completed_tests'])
                suite = ET.parse(directory / 'junit.xml').getroot()
                setup_case = next(case for case in suite if case.attrib['name'] == 'hidden setup')
                self.assertIn('late setup failure', setup_case.find('error').text)
                self.assertIn('setup.dart:77', setup_case.find('error').text)

    def test_hidden_setup_late_error_preserves_nonzero_host_and_native_exit(self):
        events = [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'hidden setup', 'hidden': True}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': True},
            {'type': 'error', 'testID': 1, 'error': 'late setup failure', 'stackTrace': 'setup.dart:77'},
            {'type': 'done', 'success': True},
        ]
        for report_type in ('host', 'native'):
            with self.subTest(report_type=report_type):
                directory = self.directory / report_type
                directory.mkdir()
                (directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))
                summary = (
                    self.host_report(directory, exit_code=17, phase='flutter-tests')
                    if report_type == 'host'
                    else self._native_report_with_exit(directory, 17)
                )

                self.assertEqual(summary['exit_code'], 17)
                self.assertEqual(summary['phase'], 'flutter-tests')
                suite = ET.parse(directory / 'junit.xml').getroot()
                setup_case = next(case for case in suite if case.attrib['name'] == 'hidden setup')
                self.assertIn('late setup failure', setup_case.find('error').text)
                self.assertIn('setup.dart:77', setup_case.find('error').text)

    def test_late_error_after_skipped_test_is_visible_and_fails_host_and_native_reports(self):
        events = [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'skipped teardown'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'skipped': True},
            {'type': 'testStart', 'test': {'id': 2, 'name': 'visible success'}},
            {'type': 'testDone', 'testID': 2, 'result': 'success'},
            {'type': 'error', 'testID': 1, 'error': 'late teardown failure', 'stackTrace': 'teardown.dart:88'},
            {'type': 'done', 'success': True},
        ]
        for report_type in ('host', 'native'):
            with self.subTest(report_type=report_type):
                directory = self.directory / report_type
                directory.mkdir()
                (directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))
                summary = self.host_report(directory) if report_type == 'host' else self._native_report_with_exit(directory, 0)

                self.assertEqual(summary['exit_code'], 1)
                self.assertEqual(summary['completed_tests'], ['skipped teardown', 'visible success'])
                self.assertEqual(summary['skipped_tests'], [])
                suite = ET.parse(directory / 'junit.xml').getroot()
                skipped_case = next(case for case in suite if case.attrib['name'] == 'skipped teardown')
                self.assertIsNone(skipped_case.find('skipped'))
                self.assertIn('late teardown failure', skipped_case.find('error').text)
                self.assertIn('teardown.dart:88', skipped_case.find('error').text)

    def _native_report_with_exit(self, directory, exit_code):
        write_run_report(
            directory, platform='tv', mode='fixtures', seed=42,
            device='emulator-5554', avd='existing_avd', exit_code=exit_code,
            phase='flutter-tests', started_at='2026-10-11T00:00:00+00:00',
        )
        return json.loads((directory / 'summary.json').read_text())

    def test_done_success_requires_literal_true_for_host_and_native_reports(self):
        done_values = {
            'true': ({'success': True}, True, True),
            'false': ({'success': False}, False, True),
            'null': ({'success': None}, False, False),
            'missing': ({}, False, False),
            'numeric': ({'success': 1}, False, False),
        }
        for report_type in ('host', 'native'):
            for label, (done_fields, passes, stream_complete) in done_values.items():
                with self.subTest(report_type=report_type, done=label):
                    directory = self.directory / f'{report_type}-{label}'
                    directory.mkdir()
                    events = [
                        {'type': 'testStart', 'test': {'id': 1, 'name': 'visible success'}},
                        {'type': 'testDone', 'testID': 1, 'result': 'success'},
                        {'type': 'done', **done_fields},
                    ]
                    (directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))
                    summary = self.host_report(directory) if report_type == 'host' else self._native_report_with_exit(directory, 0)

                    self.assertEqual(summary['status'] == 'passed', passes)
                    self.assertEqual(summary['exit_code'], 0 if passes else 1)
                    self.assertEqual(summary['event_stream_complete'], stream_complete)
                    if label == 'true':
                        self.assertEqual(summary['event_stream_issues'], [])
                    elif label == 'false':
                        self.assertIn('reported failure', summary['event_stream_issues'][0])
                    else:
                        self.assertIn('boolean success value', summary['event_stream_issues'][0])

    def test_event_after_successful_done_is_rejected_after_visible_completion(self):
        events = [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'visible success'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success'},
            {'type': 'done', 'success': True},
            {'type': 'testStart', 'test': {'id': 2, 'name': 'late event'}},
        ]
        (self.directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))

        summary = self.host_report(self.directory)

        self.assertEqual(summary['exit_code'], 1)
        self.assertTrue(summary['event_stream_complete'])
        self.assertIn('event after final done', summary['event_stream_issues'][0])

    def test_host_report_rejects_an_incomplete_stream_after_completed_tests(self):
        events = [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'completed before interruption'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success'},
        ]
        (self.directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in events))

        summary = write_host_report(
            self.directory, suite_name='unit', scope='full', selector=[],
            seed=42, exit_code=0, phase='flutter-tests', started_at='2026-10-11T00:00:00+00:00',
        )

        self.assertEqual(summary['exit_code'], 1)
        self.assertFalse(summary['event_stream_complete'])
        self.assertIn('final done event', summary['event_stream_issues'][0])
        self.assertEqual(summary['completed_tests'], ['completed before interruption'])

    def test_aggregate_rejects_successful_filtered_child(self):
        tv = self.directory / 'tv'
        mobile = self.directory / 'mobile'
        for directory, platform, scope in ((tv, 'tv', 'filtered'), (mobile, 'mobile', 'full')):
            directory.mkdir()
            (directory / 'flutter-events.jsonl').write_text('\n'.join(json.dumps(item) for item in [
                {'type': 'testStart', 'test': {'id': 1, 'name': platform}},
                {'type': 'testDone', 'testID': 1, 'result': 'success'},
                {'type': 'done', 'success': True},
            ]))
            write_run_report(
                directory, platform=platform, mode='fixtures', seed=42,
                device='emulator-5554', avd='existing_avd', exit_code=0,
                phase='complete', scope=scope, started_at='2026-10-11T00:00:00+00:00',
            )

        summary = write_aggregate(self.directory, [tv, mobile])
        self.assertEqual(summary['status'], 'failed')
        self.assertEqual(summary['scope'], 'filtered')


if __name__ == '__main__':
    unittest.main()
