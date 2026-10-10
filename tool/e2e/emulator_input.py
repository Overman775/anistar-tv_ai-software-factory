"""Check the emulator's kernel input, which synthetic Flutter key tests bypass."""

import argparse
import re
import subprocess


def has_directional_pad(devices):
    required = {'KEY_UP', 'KEY_DOWN', 'KEY_LEFT', 'KEY_RIGHT'}
    return any(
        required <= set(re.findall(r'\bKEY_[A-Z0-9_]+\b', device))
        for device in re.split(r'add device \d+:', devices)
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', required=True)
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    result = subprocess.run(
        [args.adb, '-s', args.device, 'shell', 'getevent', '-pl'],
        check=True, capture_output=True, text=True, timeout=10,
    )
    if not has_directional_pad(result.stdout):
        raise SystemExit(
            'Emulator has no hardware D-pad input. Enable hw.dPad=yes and '
            'hw.keyboard=yes in the AVD, then Cold Boot (no wipe). '
            'See docs/05_development_and_testing.md section 5.'
        )
    print('Emulator hardware D-pad input: ready.')


if __name__ == '__main__':
    main()
