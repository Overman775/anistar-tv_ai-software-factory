"""Validate public build configuration and create only a missing local prod file."""
import json
from pathlib import Path
import sys
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[2]


def validate(path):
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError, UnicodeError):
        raise ValueError(f'{path.name}: cannot read a valid JSON object') from None
    if not isinstance(data, dict) or set(data) != {'ANISTAR_MIRROR_URL'}:
        raise ValueError(f'{path.name}: expected only ANISTAR_MIRROR_URL')
    value = data['ANISTAR_MIRROR_URL']
    try:
        if (not isinstance(value, str) or any(char.isspace() for char in value)
                or any(char in value for char in ('?', '#', '\\'))):
            raise ValueError()
        uri = urlsplit(value)
        port = uri.port
        if (uri.scheme != 'https' or not uri.hostname or uri.username is not None
                or uri.password is not None or uri.path not in ('', '/')
                or uri.query or uri.fragment or (port is not None and port == 0)):
            raise ValueError()
    except ValueError:
        raise ValueError(f'{path.name}: ANISTAR_MIRROR_URL must be an HTTPS origin') from None
    return path.read_bytes()


def prepare(root=ROOT):
    validate(root / 'env/dev.json')
    prod = root / 'env/prod.json'
    if prod.exists():
        validate(prod)
        return
    template = validate(root / 'env/prod.example.json')
    try:
        with prod.open('xb') as output:
            output.write(template)
    except FileExistsError:
        # A concurrent preparation may have created it. Never overwrite it.
        validate(prod)


def main():
    try:
        prepare()
    except ValueError as error:
        sys.stderr.write(f'Environment preparation failed: {error}\n')
        return 1
    except OSError:
        # Do not stringify OS errors: they can contain user-controlled input.
        sys.stderr.write('Environment preparation failed: check env/dev.json, '
                         'env/prod.json and env/prod.example.json (valid HTTPS origin required).\n')
        return 1
    sys.stdout.write('Environment files ready: env/dev.json, env/prod.json\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
