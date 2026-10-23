"""Sanitized Android IME snapshots for the local fixture server."""
from __future__ import annotations

from dataclasses import dataclass
import re
import subprocess

IME_VISIBLE = 0x2
_TIMEOUT_SECONDS = 3


@dataclass(frozen=True)
class NativeImeSnapshot:
    available: bool
    query_succeeded: bool
    status: str
    current_editor_matches: bool

    @classmethod
    def unavailable(cls) -> 'NativeImeSnapshot':
        return cls(False, False, 'unavailable', False)

    @classmethod
    def error(cls) -> 'NativeImeSnapshot':
        return cls(True, False, 'error', False)

    def as_json(self):
        return {
            'available': self.available,
            'querySucceeded': self.query_succeeded,
            'status': self.status,
            'currentEditorMatches': self.current_editor_matches,
        }


def _bool_value(text, name):
    match = re.search(rf'\b{re.escape(name)}\s*=\s*(true|false)\b', text, re.IGNORECASE)
    return None if match is None else match.group(1).lower() == 'true'


def _int_value(text, name):
    match = re.search(rf'\b{re.escape(name)}\s*=\s*(0x[0-9a-f]+|\d+)\b', text, re.IGNORECASE)
    return None if match is None else int(match.group(1), 0)


def _current_editor_signature(input_method):
    anchor = re.search(r'\b(?:m)?curEditorInfo\s*[:=]', input_method, re.IGNORECASE)
    if anchor is None:
        return None, None
    lines = input_method[anchor.start():].splitlines()[:7]
    current = '\n'.join(lines)
    package = re.search(r'\bpackageName\s*=\s*([^\s,}]+)', current)
    action = _int_value(current, 'imeOptions')
    return (package.group(1) if package is not None else None), action


def _current_editor_matches(input_method, expected_package):
    package, action = _current_editor_signature(input_method)
    return package == expected_package and action is not None and action & 0xff == 3


def _input_method_window_flags(windows):
    sections = re.split(r'(?=\bWindow #\d+ Window\{)', windows)
    input_method_sections = []
    for section in sections:
        header = section.splitlines()[0] if section else ''
        if 'InputMethod' in header and 'InputMethodDialog' not in header:
            input_method_sections.append(section)
    if len(input_method_sections) != 1:
        return None
    return tuple(_bool_value(input_method_sections[0], name) for name in ('mHasSurface', 'isOnScreen', 'isVisible'))


def _input_method_signature(input_method):
    return (
        _current_editor_signature(input_method),
        _int_value(input_method, 'mImeWindowVis'),
        tuple(_bool_value(input_method, name) for name in ('mInputViewStarted', 'mWindowVisible', 'mDecorViewVisible')),
    )


def _foreground_matches(windows, expected_package):
    current_focus = re.search(r'\bmCurrentFocus\s*=\s*Window\{[^\n]*', windows)
    if current_focus is None:
        return None
    component = re.search(r'\b([A-Za-z][A-Za-z0-9_.]*)/[A-Za-z0-9_.$]+', current_focus.group(0))
    return component is not None and component.group(1) == expected_package


def parse_native_ime(input_method, windows, expected_package):
    ime_window_vis = _int_value(input_method, 'mImeWindowVis')
    service_flags = tuple(_bool_value(input_method, name) for name in (
        'mInputViewStarted',
        'mWindowVisible',
        'mDecorViewVisible',
    ))
    window_flags = _input_method_window_flags(windows)
    foreground_matches = _foreground_matches(windows, expected_package)
    if ime_window_vis is None or None in service_flags or window_flags is None or None in window_flags or foreground_matches is None:
        return NativeImeSnapshot.error()

    editor_matches = _current_editor_matches(input_method, expected_package)
    visible = (
        foreground_matches
        and editor_matches
        and ime_window_vis & IME_VISIBLE != 0
        and all(service_flags)
        and all(window_flags)
    )
    hidden = (
        foreground_matches
        and ime_window_vis & IME_VISIBLE == 0
        and not any(service_flags)
        and not any(window_flags)
    )
    if visible:
        return NativeImeSnapshot(True, True, 'visible', True)
    if hidden:
        return NativeImeSnapshot(True, True, 'hidden', editor_matches)
    return NativeImeSnapshot(True, True, 'transition', editor_matches)


def _dump(adb, device, *service):
    try:
        completed = subprocess.run(
            [adb, '-s', device, 'shell', 'dumpsys', *service],
            check=False,
            capture_output=True,
            text=True,
            timeout=_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return completed.stdout if completed.returncode == 0 else None


def read_native_ime(adb, device, expected_package):
    if not adb or not device or not expected_package:
        return NativeImeSnapshot.unavailable()
    initial_input_method = _dump(adb, device, 'input_method')
    windows = _dump(adb, device, 'window')
    current_input_method = _dump(adb, device, 'input_method')
    if initial_input_method is None or windows is None or current_input_method is None:
        return NativeImeSnapshot.error()
    snapshot = parse_native_ime(current_input_method, windows, expected_package)
    if snapshot.status == 'error' or _input_method_signature(initial_input_method) == _input_method_signature(current_input_method):
        return snapshot
    return NativeImeSnapshot(True, True, 'transition', snapshot.current_editor_matches)
