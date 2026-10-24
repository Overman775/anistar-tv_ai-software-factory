"""Validate selector JSON and optionally append it to an argv command."""

import argparse
import json
import os
import sys


ENVIRONMENT_VARIABLE = 'ANISTAR_TEST_SELECTORS_JSON'
NAME_OPTIONS = ('--plain-name', '--name')


class SelectorError(ValueError):
    """A selector transport is malformed or outside the selected profile."""


def load_selectors(raw):
    try:
        selectors = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SelectorError(f'{ENVIRONMENT_VARIABLE} must contain a JSON array.') from error
    if not isinstance(selectors, list) or not selectors:
        raise SelectorError(f'{ENVIRONMENT_VARIABLE} must contain a non-empty JSON array.')
    if any(not isinstance(selector, str) or not selector for selector in selectors):
        raise SelectorError(f'{ENVIRONMENT_VARIABLE} values must be non-empty strings.')
    if any('\0' in selector for selector in selectors):
        raise SelectorError(f'{ENVIRONMENT_VARIABLE} values cannot contain NUL characters.')
    return selectors


def validate(selectors, *, profile):
    index = 0
    while index < len(selectors):
        selector = selectors[index]
        if selector in NAME_OPTIONS:
            if index + 1 >= len(selectors) or selectors[index + 1].startswith('--'):
                raise SelectorError(f'Missing value for {selector}.')
            index += 2
            continue
        if selector.startswith('--plain-name=') or selector.startswith('--name='):
            if not selector.partition('=')[2]:
                raise SelectorError(f'Missing value for {selector.partition("=")[0]}.')
            index += 1
            continue
        if selector.startswith('--'):
            raise SelectorError(
                f'Unsupported Flutter test option: {selector}. Use a test path, --plain-name, or --name.',
            )
        if profile == 'e2e':
            raise SelectorError('E2E selectors must use --plain-name or --name.')
        index += 1
    return selectors


def selectors_from_environment(profile):
    raw = os.environ.get(ENVIRONMENT_VARIABLE, '')
    if not raw:
        return []
    return validate(load_selectors(raw), profile=profile)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=('host', 'e2e'), required=True)
    parser.add_argument('command', choices=('validate', 'exec'))
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        selectors = selectors_from_environment(args.profile)
    except SelectorError as error:
        parser.error(str(error))
    if args.command == 'validate':
        if args.arguments:
            parser.error('validate does not accept a command.')
        return
    command = args.arguments
    if command[:1] == ['--']:
        command = command[1:]
    if not command:
        parser.error('exec requires a command after --.')
    child_environment = os.environ.copy()
    child_environment.pop(ENVIRONMENT_VARIABLE, None)
    os.execvpe(command[0], [*command, *selectors], child_environment)


if __name__ == '__main__':
    main()
