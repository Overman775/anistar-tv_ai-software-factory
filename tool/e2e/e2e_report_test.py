"""Runner failures and platform results must remain visible to CI."""

import json
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from e2e_report import write_aggregate, write_run_report


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
        ], [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'skipped'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'skipped': True},
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
        ]))
        self.report(self.directory)
        summary = json.loads((self.directory / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'failed')
        self.assertEqual(summary['exit_code'], 1)
        self.assertEqual(summary['errors'], 1)


if __name__ == '__main__':
    unittest.main()
