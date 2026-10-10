"""Regressions for an AVD with D-pad enabled but no keyboard device."""

import unittest

from emulator_input import has_directional_pad


class EmulatorInputTest(unittest.TestCase):
    def test_accepts_arrow_keys_on_one_hardware_device(self):
        self.assertTrue(has_directional_pad(
            'add device 1: /dev/input/event0\n name: "qwerty2"\n'
            'KEY_UP KEY_LEFT KEY_RIGHT KEY_DOWN KEY_ENTER'
        ))

    def test_rejects_touchscreen_and_power_only(self):
        self.assertFalse(has_directional_pad(
            'add device 1: /dev/input/event0\n KEY_POWER\n'
            'add device 2: /dev/input/event1\n BTN_STYLUS ABS_X ABS_Y'
        ))

    def test_does_not_combine_keys_from_different_devices(self):
        self.assertFalse(has_directional_pad(
            'add device 1: /dev/input/event0\n KEY_UP KEY_DOWN\n'
            'add device 2: /dev/input/event1\n KEY_LEFT KEY_RIGHT'
        ))

    def test_requires_exact_key_names_and_all_directions(self):
        for keys in ('', 'KEY_UP KEY_DOWN KEY_LEFT', 'KEY_UP KEY_DOWN KEY_LEFTCTRL KEY_RIGHTCTRL'):
            with self.subTest(keys=keys):
                self.assertFalse(has_directional_pad('add device 1: /dev/input/event0\n' + keys))


if __name__ == '__main__':
    unittest.main()
