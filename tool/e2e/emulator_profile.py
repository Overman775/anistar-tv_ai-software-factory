"""Verify the Android system role before running TV or mobile E2E."""

import argparse
import re
import subprocess


def current_ui_mode_type(state):
    match = re.search(r'\bmCurUiMode=0x([0-9a-fA-F]+)\b', state)
    if match is None:
        raise ValueError('Android did not report mCurUiMode; cannot verify emulator profile.')
    return int(match.group(1), 16) & 0x0f


def verify_profile(state, expected):
    television = current_ui_mode_type(state) == 4
    if television != (expected == 'tv'):
        raise ValueError(
            f'Expected {expected} Android system, but emulator reports '
            f'{"TV" if television else "non-TV"} UI mode. '
            'Screen size and TV hardware skin do not change the system role. '
            'Use an android-tv/google-tv system image for TV E2E, '
            'or fixtures-mobile on a phone image.'
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--expected', choices=('tv', 'mobile'), required=True)
    args = parser.parse_args()
    result = subprocess.run(
        [args.adb, '-s', args.device, 'shell', 'dumpsys', 'uimode'],
        check=True, capture_output=True, text=True, timeout=10,
    )
    try:
        verify_profile(result.stdout, args.expected)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print(f'Emulator Android system profile: {args.expected}.')


if __name__ == '__main__':
    main()
