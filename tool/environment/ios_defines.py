"""Compose Xcode flavor defines without changing Flutter-generated files."""
import base64
import json
import os
from pathlib import Path


def compose(flavor, encoded, root):
    config = json.loads((root / f'env/{flavor}.json').read_text())
    replacements = {**config, 'FLUTTER_APP_FLAVOR': flavor}
    retained = []
    for part in encoded.split(','):
        if part:
            value = base64.b64decode(part, validate=True).decode('utf-8')
            key = value.partition('=')[0]
            # Generated.xcconfig may come from a previous integration/live run.
            # Carry Flutter tooling metadata, never stale account/test defines.
            if key.startswith(('FLUTTER_', 'dart.')) and key not in replacements:
                retained.append(value)
    retained.extend(f'{key}={value}' for key, value in replacements.items())
    return ','.join(base64.b64encode(value.encode()).decode() for value in retained)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[2]
    flavor = os.environ['ANISTAR_FLAVOR']
    if flavor not in ('dev', 'prod'):
        raise SystemExit('Invalid iOS flavor')
    try:
        result = compose(flavor, os.environ.get('DART_DEFINES', ''), root)
    except (OSError, ValueError, UnicodeError):
        raise SystemExit('Cannot prepare iOS build defines') from None
    # This is machine input to the build phase, never a diagnostic log.
    os.sys.stdout.write(result)
