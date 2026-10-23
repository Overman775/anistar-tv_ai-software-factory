import subprocess
import unittest
from unittest.mock import patch

from native_ime import NativeImeSnapshot, parse_native_ime, read_native_ime


VISIBLE_INPUT = '''
mImeWindowVis=3
mInputViewStarted=true
mWindowVisible=true
mDecorViewVisible=true
mCurEditorInfo=EditorInfo {
 packageName=com.anistar.tv.dev
 inputType=0x8001
 imeOptions=0x2000003
}
'''
HIDDEN_INPUT = '''
mImeWindowVis=0
mInputViewStarted=false
mWindowVisible=false
mDecorViewVisible=false
mCurEditorInfo=EditorInfo {
 packageName=com.anistar.tv.dev
 inputType=0x8001
 imeOptions=0x2000003
}
'''
VISIBLE_WINDOWS = '''
mCurrentFocus=Window{abc u0 com.anistar.tv.dev/com.anistar.tv.MainActivity}
Window #4 Window{def u0 InputMethod}
 mHasSurface=true
 isOnScreen=true
 isVisible=true
'''
HIDDEN_WINDOWS = '''
mCurrentFocus=Window{abc u0 com.anistar.tv.dev/com.anistar.tv.MainActivity}
Window #4 Window{def u0 InputMethod}
 mHasSurface=false
 isOnScreen=false
 isVisible=false
'''


class NativeImeTest(unittest.TestCase):
    def test_visible_requires_current_search_editor_and_all_current_flags(self):
        snapshot = parse_native_ime(VISIBLE_INPUT, VISIBLE_WINDOWS, 'com.anistar.tv.dev')

        self.assertEqual(snapshot, NativeImeSnapshot(True, True, 'visible', True))

    def test_hidden_accepts_editor_zero_only_after_a_successful_hidden_sample(self):
        input_method = HIDDEN_INPUT.replace(' packageName=com.anistar.tv.dev\n inputType=0x8001\n imeOptions=0x2000003\n', '')
        snapshot = parse_native_ime(input_method, HIDDEN_WINDOWS, 'com.anistar.tv.dev')

        self.assertEqual(snapshot, NativeImeSnapshot(True, True, 'hidden', False))

    def test_partial_and_contradictory_flags_are_transition_not_hidden(self):
        partial = VISIBLE_INPUT.replace('mDecorViewVisible=true', 'mDecorViewVisible=false')
        contradictory = HIDDEN_INPUT.replace('mImeWindowVis=0', 'mImeWindowVis=3')

        self.assertEqual(parse_native_ime(partial, VISIBLE_WINDOWS, 'com.anistar.tv.dev').status, 'transition')
        self.assertEqual(parse_native_ime(contradictory, HIDDEN_WINDOWS, 'com.anistar.tv.dev').status, 'transition')

    def test_stale_history_editor_and_wrong_foreground_never_confirm_visible(self):
        stale = VISIBLE_INPUT.replace('mCurEditorInfo', 'mLastEditorInfo')
        wrong_foreground = VISIBLE_WINDOWS.replace('com.anistar.tv.dev', 'com.android.launcher')

        self.assertEqual(parse_native_ime(stale, VISIBLE_WINDOWS, 'com.anistar.tv.dev').status, 'transition')
        self.assertEqual(parse_native_ime(VISIBLE_INPUT, wrong_foreground, 'com.anistar.tv.dev').status, 'transition')

    def test_foreground_package_must_match_the_component_exactly(self):
        similar_package = VISIBLE_WINDOWS.replace('com.anistar.tv.dev/', 'com.anistar.tv.dev.other/')

        self.assertEqual(parse_native_ime(VISIBLE_INPUT, similar_package, 'com.anistar.tv.dev').status, 'transition')

    def test_wrong_current_editor_action_is_transition(self):
        wrong_action = VISIBLE_INPUT.replace('imeOptions=0x2000003', 'imeOptions=0x2000005')

        self.assertEqual(parse_native_ime(wrong_action, VISIBLE_WINDOWS, 'com.anistar.tv.dev').status, 'transition')

    def test_missing_required_parser_field_is_error(self):
        missing = VISIBLE_WINDOWS.replace('isVisible=true', '')

        self.assertEqual(parse_native_ime(VISIBLE_INPUT, missing, 'com.anistar.tv.dev'), NativeImeSnapshot.error())

    def test_multiple_input_method_windows_fail_closed(self):
        ambiguous_windows = VISIBLE_WINDOWS + '''
Window #5 Window{ghi u0 InputMethod}
 mHasSurface=true
 isOnScreen=true
 isVisible=true
'''

        self.assertEqual(parse_native_ime(VISIBLE_INPUT, ambiguous_windows, 'com.anistar.tv.dev'), NativeImeSnapshot.error())

    @patch('native_ime.subprocess.run')
    def test_reader_uses_the_full_window_dump_for_current_focus(self, run):
        run.side_effect = [
            subprocess.CompletedProcess(['adb'], 0, stdout=VISIBLE_INPUT),
            subprocess.CompletedProcess(['adb'], 0, stdout=VISIBLE_WINDOWS),
            subprocess.CompletedProcess(['adb'], 0, stdout=VISIBLE_INPUT),
        ]

        snapshot = read_native_ime('adb', 'emulator-5554', 'com.anistar.tv.dev')

        self.assertEqual(snapshot, NativeImeSnapshot(True, True, 'visible', True))
        self.assertEqual(
            [call.args[0] for call in run.call_args_list],
            [
                ['adb', '-s', 'emulator-5554', 'shell', 'dumpsys', 'input_method'],
                ['adb', '-s', 'emulator-5554', 'shell', 'dumpsys', 'window'],
                ['adb', '-s', 'emulator-5554', 'shell', 'dumpsys', 'input_method'],
            ],
        )

    @patch('native_ime.subprocess.run')
    def test_reader_marks_a_changed_input_snapshot_as_transition(self, run):
        changed = VISIBLE_INPUT.replace('imeOptions=0x2000003', 'imeOptions=0x2000005')
        run.side_effect = [
            subprocess.CompletedProcess(['adb'], 0, stdout=VISIBLE_INPUT),
            subprocess.CompletedProcess(['adb'], 0, stdout=VISIBLE_WINDOWS),
            subprocess.CompletedProcess(['adb'], 0, stdout=changed),
        ]

        snapshot = read_native_ime('adb', 'emulator-5554', 'com.anistar.tv.dev')

        self.assertEqual(snapshot, NativeImeSnapshot(True, True, 'transition', False))

    @patch('native_ime.subprocess.run')
    def test_subprocess_timeout_fails_closed(self, run):
        run.side_effect = subprocess.TimeoutExpired(['adb'], 3)

        self.assertEqual(read_native_ime('adb', 'emulator-5554', 'com.anistar.tv.dev'), NativeImeSnapshot.error())

    @patch('native_ime.subprocess.run')
    def test_subprocess_failure_fails_closed(self, run):
        run.return_value = subprocess.CompletedProcess(['adb'], 1, stdout='', stderr='ignored')

        self.assertEqual(read_native_ime('adb', 'emulator-5554', 'com.anistar.tv.dev'), NativeImeSnapshot.error())


if __name__ == '__main__':
    unittest.main()
