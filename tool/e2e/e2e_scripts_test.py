"""Shell entry points must fail safely before SDK/build work on bad devices."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from emulator_selection_test import FAKE_ADB


class E2eScriptsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / 'project'
        (self.project / 'scripts').mkdir(parents=True)
        (self.project / 'tool/e2e').mkdir(parents=True)
        source = Path(__file__).resolve().parents[2]
        for name in ('e2e.sh', 'e2e-tv.sh', 'e2e-mobile.sh', 'e2e-all.sh'):
            shutil.copyfile(source / 'scripts' / name, self.project / 'scripts' / name)
        for name in ('emulator_selection.py', 'emulator_profile.py', 'e2e_report.py'):
            shutil.copyfile(source / 'tool/e2e' / name, self.project / 'tool/e2e' / name)
        self.state_file = Path(self.temp.name) / 'state.json'
        self.sdk = Path(self.temp.name) / 'android'
        (self.sdk / 'platform-tools').mkdir(parents=True)
        adb = self.sdk / 'platform-tools/adb'
        adb.write_text(f'#!{sys.executable}\n' + FAKE_ADB)
        adb.chmod(0o755)
        # No Flutter executable is present: these negative runs must never
        # reach SDK/build work, much less the user's real Flutter installation.
        self.environment = {
            **os.environ, 'ANDROID_HOME': str(self.sdk),
            'ANISTAR_FAKE_ADB_STATE': str(self.state_file),
            'ANISTAR_FLUTTER_SDK': str(Path(self.temp.name) / 'missing-flutter'),
            'ANISTAR_TV_AVD': 'anistar_tv_e2e',
            'ANISTAR_MOBILE_AVD': 'anistar_mobile_e2e',
            'ANISTAR_TEST_SEED': '42',
        }
        self.environment.pop('ANISTAR_E2E_RUN_DIR', None)

    def cli(self, script, items, *args):
        self.state_file.write_text(json.dumps(items))
        return subprocess.run(
            ['bash', str(self.project / 'scripts' / script), *args],
            capture_output=True, text=True, env=self.environment, timeout=15,
        )

    def fake_successful_build_tools(self):
        # All commands remain inside this temporary project. The fixture stub
        # writes readiness without opening any socket, and adb never touches a
        # real device. This exercises runner ordering/reporting and cleanup.
        adb = self.sdk / 'platform-tools/adb'
        adb.write_text(f'#!{sys.executable}\n' + FAKE_ADB.replace(
            'else:\n    print',
            "elif command[:3] == ['shell', 'settings', 'get']:\n    print('null')\n"
            "elif command[:2] == ['shell', 'settings'] or command[:1] == ['reverse']:\n    pass\n"
            'else:\n    print',
        ))
        (self.project / 'tool/e2e/emulator_input.py').write_text('')
        (self.project / 'tool/e2e/fake_infrastructure_test.py').write_text('''
import os, unittest
from pathlib import Path
class IsolatedInfrastructureTest(unittest.TestCase):
    def test_state_is_local_fixture(self):
        self.assertTrue(Path(os.environ['ANISTAR_FAKE_ADB_STATE']).is_file())
''')
        (self.project / 'tool/e2e/fixture_server.py').write_text('''
import argparse, signal
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--ready-file')
parser.add_argument('--event-log')
args=parser.parse_args()
Path(args.ready_file).write_text('50234')
Path(args.event_log).write_text('')
signal.pause()
''')
        sdk = Path(self.environment['ANISTAR_FLUTTER_SDK'])
        (sdk / 'bin').mkdir(parents=True)
        dart = sdk / 'bin/dart'
        dart.write_text(f'#!{sys.executable}\nimport sys\nsys.stdin.read()\n')
        dart.chmod(0o755)
        flutter = sdk / 'bin/flutter'
        flutter.write_text(f'#!{sys.executable}\n' + '''
import json, os, sys
from pathlib import Path
args=sys.argv[1:]
if '--version' in args:
    print('{}')
elif 'test' in args:
    tv=any(arg.endswith('/app_e2e_test.dart') for arg in args)
    status=int(os.environ.get('ANISTAR_FAKE_TV_EXIT', '0')) if tv else 0
    if not os.environ.get('ANISTAR_FAKE_NO_EVENTS'):
        report=next(arg.split('json:',1)[1] for arg in args if arg.startswith('--file-reporter=json:'))
        events=[{'type':'testStart','test':{'id':1,'name':'native fixture case'}},
                {'type':'testDone','testID':1,'result':'failure' if status else 'success','hidden':False}]
        Path(report).write_text('\\n'.join(json.dumps(event) for event in events))
    print('FAKE SDK test invocation')
    raise SystemExit(status)
''')
        flutter.chmod(0o755)

    def ready_devices(self):
        return [
            {'device': 'emulator-5556', 'avd': 'anistar_tv_e2e', 'uimode': 'mCurUiMode=0x14'},
            {'device': 'emulator-5554', 'avd': 'anistar_mobile_e2e'},
        ]

    def test_tv_live_mode_without_device_still_selects_named_tv_avd(self):
        result = self.cli('e2e-tv.sh', [{'device': 'emulator-5554', 'avd': 'anistar_tv_e2e'}], 'live')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Expected tv', result.stdout)
        summaries = list((self.project / 'build/e2e').glob('*/summary.json'))
        self.assertEqual(len(summaries), 1)
        summary = json.loads(summaries[0].read_text())
        self.assertEqual(summary['mode'], 'live')
        self.assertEqual(summary['phase'], 'preflight')
        self.assertEqual(summary['errors'], 1)
        self.assertIsNone(summary['avd'])
        self.assertEqual(summary['requested_avd'], 'anistar_tv_e2e')
        self.assertNotIn('missing-flutter/bin/flutter', result.stdout)

    def test_all_keeps_both_preflight_failures_and_does_not_stop_after_tv(self):
        result = self.cli('e2e-all.sh', [
            {'device': 'emulator-5554', 'avd': 'anistar_tv_e2e'},
            {'device': 'emulator-5556', 'avd': 'anistar_mobile_e2e', 'uimode': 'mCurUiMode=0x14'},
        ])
        self.assertNotEqual(result.returncode, 0)
        summaries = list((self.project / 'build/e2e').glob('all-*/summary.json'))
        self.assertEqual(len(summaries), 1)
        summary = json.loads(summaries[0].read_text())
        self.assertEqual([run['platform'] for run in summary['runs']], ['tv', 'mobile'])
        self.assertEqual([run['phase'] for run in summary['runs']], ['preflight', 'preflight'])
        self.assertTrue(all(run['exit_code'] != 0 for run in summary['runs']))
        self.assertTrue((summaries[0].parent / 'junit.xml').exists())
        self.assertNotIn('missing-flutter/bin/flutter', result.stdout)

    def test_all_rejects_same_device_for_explicit_and_mixed_overrides(self):
        items = [{'device': 'emulator-5554', 'avd': 'anistar_tv_e2e', 'uimode': 'mCurUiMode=0x14'}]
        result = self.cli('e2e-all.sh', items, 'emulator-5554', 'emulator-5554')
        self.assertEqual(result.returncode, 64)
        self.assertIn('different emulators', result.stderr)
        result = self.cli('e2e-all.sh', items, '', 'emulator-5554')
        self.assertEqual(result.returncode, 64)
        self.assertIn('same emulator', result.stderr)
        self.assertFalse((self.project / 'build/e2e').exists())

    def test_mobile_wrapper_rejects_unexpected_mode_or_extra_arguments(self):
        for args in (('live',), ('emulator-5554', 'fixtures')):
            with self.subTest(args=args):
                result = self.cli('e2e-mobile.sh', [], *args)
                self.assertEqual(result.returncode, 64)
                self.assertFalse((self.project / 'build/e2e').exists())

    def test_nonempty_explicit_run_directory_is_preserved_and_rejected(self):
        directory = self.project / 'existing-run'
        directory.mkdir()
        (directory / 'port').write_text('old fixture port')
        (directory / 'flutter-events.jsonl').write_text('old successful test results')
        self.environment['ANISTAR_E2E_RUN_DIR'] = str(directory)
        result = self.cli('e2e-mobile.sh', [])
        self.assertEqual(result.returncode, 64)
        self.assertIn('Refusing to reuse nonempty', result.stderr)
        self.assertEqual((directory / 'port').read_text(), 'old fixture port')
        self.assertEqual((directory / 'flutter-events.jsonl').read_text(), 'old successful test results')
        self.assertFalse((directory / 'summary.json').exists())

    def test_all_runs_mobile_after_failed_tv_test_and_releases_shared_build_lock(self):
        self.fake_successful_build_tools()
        self.environment['ANISTAR_FAKE_TV_EXIT'] = '4'
        result = self.cli('e2e-all.sh', self.ready_devices())
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count('FAKE SDK test invocation'), 2)
        summary_file = next((self.project / 'build/e2e').glob('all-*/summary.json'))
        summary = json.loads(summary_file.read_text())
        self.assertEqual([run['exit_code'] for run in summary['runs']], [4, 0])
        self.assertEqual([run['status'] for run in summary['runs']], ['failed', 'passed'])
        self.assertEqual([run['native_tests'] for run in summary['runs']], [1, 1])
        self.assertFalse((self.project / 'build/e2e/.flutter.lock').exists())

    def test_successful_sdk_without_native_events_fails_closed(self):
        self.fake_successful_build_tools()
        self.environment['ANISTAR_FAKE_NO_EVENTS'] = '1'
        result = self.cli('e2e-mobile.sh', self.ready_devices())
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        summary_file = next((self.project / 'build/e2e').glob('*/summary.json'))
        summary = json.loads(summary_file.read_text())
        self.assertEqual(summary['phase'], 'report-validation')
        self.assertEqual(summary['native_tests'], 0)
        self.assertFalse((self.project / 'build/e2e/.flutter.lock').exists())

    def test_report_helper_failure_changes_successful_runner_exit_code(self):
        self.fake_successful_build_tools()
        (self.project / 'tool/e2e/e2e_report.py').write_text('raise SystemExit(9)\n')
        result = self.cli('e2e-mobile.sh', self.ready_devices())
        self.assertEqual(result.returncode, 9, result.stdout + result.stderr)
        self.assertIn('FAKE SDK test invocation', result.stdout)
        self.assertFalse((self.project / 'build/e2e/.flutter.lock').exists())


if __name__ == '__main__':
    unittest.main()
