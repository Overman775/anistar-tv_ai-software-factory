"""A TV skin on a phone system image must not pass TV preflight."""

import unittest

from emulator_profile import current_ui_mode_type, verify_profile


class EmulatorProfileTest(unittest.TestCase):
    def test_tv_type_ignores_day_and_night_bits(self):
        for value in ('14', '24'):
            with self.subTest(value=value):
                state = f'mCurUiMode=0x{value} mSetUiMode=0x11'
                self.assertEqual(current_ui_mode_type(state), 4)
                verify_profile(state, 'tv')

    def test_phone_image_rejected_for_tv_even_with_tv_skin(self):
        with self.assertRaisesRegex(ValueError, 'Screen size and TV hardware skin'):
            verify_profile('mCurUiMode=0x11 mSetUiMode=0x14', 'tv')

    def test_phone_image_accepted_for_mobile(self):
        verify_profile('mCurUiMode=0x21', 'mobile')

    def test_tv_image_rejected_for_mobile(self):
        with self.assertRaisesRegex(ValueError, 'Expected mobile'):
            verify_profile('mCurUiMode=0x14', 'mobile')

    def test_missing_current_mode_fails_closed(self):
        for state in ('', 'mSetUiMode=0x14', 'mCurUiMode=unavailable'):
            with self.subTest(state=state), self.assertRaisesRegex(ValueError, 'cannot verify'):
                verify_profile(state, 'tv')


if __name__ == '__main__':
    unittest.main()
