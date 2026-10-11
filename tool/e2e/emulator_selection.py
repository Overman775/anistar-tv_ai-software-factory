"""Select a running named AVD, then verify boot readiness and Android role."""

import argparse
import json
import re
import shlex
import subprocess
from dataclasses import dataclass

from emulator_profile import verify_profile


class SelectionError(ValueError):
    pass


@dataclass
class Emulator:
    device: str
    state: str
    avd: str | None = None


def adb_read(adb, *args):
    try:
        result = subprocess.run(
            [adb, *args], capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise SelectionError(f'Cannot read emulator state with adb: {error}') from error
    if result.returncode != 0:
        raise SelectionError(result.stderr.strip() or result.stdout.strip() or 'adb command failed.')
    return result.stdout.replace('\r', '').strip()


def running_emulators(adb):
    emulators = []
    for line in adb_read(adb, 'devices').splitlines():
        parts = line.split()
        if len(parts) < 2 or re.fullmatch(r'emulator-[0-9]+', parts[0]) is None:
            continue
        emulator = Emulator(device=parts[0], state=parts[1])
        if emulator.state == 'device':
            try:
                lines = adb_read(adb, '-s', emulator.device, 'emu', 'avd', 'name').splitlines()
                emulator.avd = next((line for line in lines if line and line != 'OK'), None)
            except SelectionError:
                # Still report this emulator rather than silently choosing another one.
                pass
        emulators.append(emulator)
    return emulators


def describe(emulators):
    return ', '.join(f'{item.avd or "<name unavailable>"} ({item.device}, {item.state})' for item in emulators) or 'none'


def select_emulator(adb, *, avd, expected, device=None, emulator_command='emulator', identity_only=False):
    if device is not None and re.fullmatch(r'emulator-[0-9]+', device) is None:
        raise SelectionError('Device override must be emulator-<port>; physical devices are not selected by this runner.')
    emulators = running_emulators(adb)
    if device is not None:
        matches = [item for item in emulators if item.device == device]
        if not matches:
            raise SelectionError(f'{device} is not connected. Running emulator names: {describe(emulators)}.')
    else:
        matches = [item for item in emulators if item.avd == avd]
        if not matches:
            command = shlex.join([emulator_command, '-avd', avd])
            raise SelectionError(
                f'No running emulator named {avd!r}. Start the existing AVD with:\n'
                f'  {command}\nRunning emulator names: {describe(emulators)}. '
                'This script never creates or resets an AVD.'
            )
        if len(matches) > 1:
            raise SelectionError(
                f'Multiple running emulators have AVD name {avd!r}: {describe(matches)}. '
                'Pass an explicit emulator-<port> override.'
            )
    selected = matches[0]
    if selected.state != 'device':
        raise SelectionError(f'{selected.device} is {selected.state}, not ready. Running emulator names: {describe(emulators)}.')
    if not selected.avd:
        raise SelectionError(f'{selected.device} did not report its AVD name; cannot identify the running emulator.')
    if adb_read(adb, '-s', selected.device, 'get-state') != 'device':
        raise SelectionError(f'{selected.avd} ({selected.device}) is no longer ready.')
    if adb_read(adb, '-s', selected.device, 'shell', 'getprop', 'sys.boot_completed') != '1':
        raise SelectionError(f'{selected.avd} ({selected.device}) has not completed Android boot. Wait for it to finish and retry.')
    if not identity_only:
        state = adb_read(adb, '-s', selected.device, 'shell', 'dumpsys', 'uimode')
        try:
            verify_profile(state, expected)
        except ValueError as error:
            raise SelectionError(f'{selected.avd} ({selected.device}): {error}') from error
    return {'device': selected.device, 'avd': selected.avd, 'profile': None if identity_only else expected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', required=True)
    parser.add_argument('--avd', required=True)
    parser.add_argument('--expected', choices=('tv', 'mobile'), required=True)
    parser.add_argument('--device')
    parser.add_argument('--emulator', default='emulator')
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--identity-only', action='store_true', help='Read identity for all-runner duplicate detection; does not authorize a test run.')
    args = parser.parse_args()
    try:
        selected = select_emulator(
            args.adb, avd=args.avd, expected=args.expected, device=args.device,
            emulator_command=args.emulator,
            identity_only=args.identity_only,
        )
    except SelectionError as error:
        parser.exit(1, f'{error}\n')
    print(json.dumps(selected) if args.json else selected['device'])


if __name__ == '__main__':
    main()
