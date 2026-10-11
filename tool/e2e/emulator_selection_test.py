"""Exercise the real selector CLI against a read-only fake adb executable."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


FAKE_ADB = '''
import json, os, sys
items = json.load(open(os.environ['ANISTAR_FAKE_ADB_STATE']))
args = sys.argv[1:]
if args == ['devices']:
    print('List of devices attached')
    for item in items:
        print(item['device'] + '\\t' + item.get('state', 'device'))
    raise SystemExit(0)
item = next((item for item in items if args[:2] == ['-s', item['device']]), None)
if item is None:
    raise SystemExit(1)
command = args[2:]
if command == ['emu', 'avd', 'name']:
    print(item['avd'] + '\\nOK')
elif command == ['get-state']:
    print(item.get('current_state', item.get('state', 'device')))
elif command == ['shell', 'getprop', 'sys.boot_completed']:
    print(item.get('boot', '1'))
elif command == ['shell', 'dumpsys', 'uimode']:
    print(item.get('uimode', 'mCurUiMode=0x11'))
else:
    print('Unexpected adb command: ' + repr(command), file=sys.stderr)
    raise SystemExit(77)
'''


class EmulatorSelectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.state_file = self.directory / 'state.json'
        self.adb = self.directory / 'adb'
        self.adb.write_text(f'#!{sys.executable}\n' + FAKE_ADB)
        self.adb.chmod(0o755)
        self.environment = {**os.environ, 'ANISTAR_FAKE_ADB_STATE': str(self.state_file)}

    def cli(self, items, *extra):
        self.state_file.write_text(json.dumps(items))
        return subprocess.run(
            [sys.executable, str(Path(__file__).with_name('emulator_selection.py')),
             '--adb', str(self.adb), '--avd', 'anistar_tv_e2e', '--expected', 'tv',
             '--emulator', '/sdk/emulator/emulator', '--json', *extra],
            capture_output=True, text=True, env=self.environment, timeout=10,
        )

    def test_named_avd_wins_over_first_emulator_and_physical_device(self):
        result = self.cli([
            {'device': 'emulator-5554', 'avd': 'anistar_mobile_e2e'},
            {'device': 'physical123', 'avd': 'not-an-avd'},
            {'device': 'emulator-5556', 'avd': 'anistar_tv_e2e', 'uimode': 'mCurUiMode=0x14'},
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            'device': 'emulator-5556', 'avd': 'anistar_tv_e2e', 'profile': 'tv',
        })

    def test_missing_default_reports_start_command_and_running_names(self):
        result = self.cli([{'device': 'emulator-5554', 'avd': 'existing_phone'}])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('/sdk/emulator/emulator -avd anistar_tv_e2e', result.stderr)
        self.assertIn('existing_phone (emulator-5554, device)', result.stderr)
        self.assertEqual(result.stdout, '')

    def test_duplicate_name_requires_explicit_device(self):
        items = [
            {'device': device, 'avd': 'anistar_tv_e2e', 'uimode': 'mCurUiMode=0x14'}
            for device in ('emulator-5554', 'emulator-5556')
        ]
        result = self.cli(items)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Multiple running emulators', result.stderr)
        result = self.cli(items, '--device', 'emulator-5556')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['device'], 'emulator-5556')

    def test_offline_override_is_rejected(self):
        result = self.cli([{'device': 'emulator-5554', 'avd': 'anistar_tv_e2e', 'state': 'offline'}], '--device', 'emulator-5554')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('offline, not ready', result.stderr)

    def test_booting_named_emulator_is_rejected(self):
        result = self.cli([{'device': 'emulator-5554', 'avd': 'anistar_tv_e2e', 'boot': '0'}])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('has not completed Android boot', result.stderr)

    def test_emulator_that_disconnects_during_selection_is_rejected(self):
        result = self.cli([{'device': 'emulator-5554', 'avd': 'anistar_tv_e2e', 'current_state': 'offline'}])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no longer ready', result.stderr)

    def test_explicit_override_still_requires_correct_profile(self):
        result = self.cli([{'device': 'emulator-5554', 'avd': 'phone'}], '--device', 'emulator-5554')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Expected tv', result.stderr)
        result = self.cli(
            [{'device': 'emulator-5554', 'avd': 'tv', 'uimode': 'mCurUiMode=0x14'}],
            '--device', 'emulator-5554', '--expected', 'mobile',
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Expected mobile', result.stderr)

    def test_invalid_device_argument_and_unknown_override_fail_closed(self):
        for device in ('physical123', 'emulator-5554; touch something', 'emulator-', 'emulator-abc'):
            with self.subTest(device=device):
                result = self.cli([], '--device', device)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Device override must be emulator-', result.stderr)
        result = self.cli([], '--device', 'emulator-5554')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not connected', result.stderr)

    def test_identity_check_for_all_runner_does_not_claim_verified_profile(self):
        result = self.cli([{'device': 'emulator-5554', 'avd': 'anistar_tv_e2e'}], '--identity-only')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(json.loads(result.stdout)['profile'])


if __name__ == '__main__':
    unittest.main()
