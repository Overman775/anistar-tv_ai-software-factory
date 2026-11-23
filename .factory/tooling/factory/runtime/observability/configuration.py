"""Validate public receiver settings without accessing credentials."""

import re
from typing import Annotated
from urllib.parse import urlsplit

from pydantic import AfterValidator, ConfigDict, with_config
from typing_extensions import TypedDict

SECRET_REFERENCE = re.compile(r"\$\{env:([A-Za-z_][A-Za-z0-9_]*)\}")
_RESERVED = {"content-length", "content-type", "host", "transfer-encoding"}


@with_config(ConfigDict(strict=True, extra="forbid"))
class TelemetryOptions(TypedDict, total=False):
    enabled: bool
    endpoint: str
    headers: dict[str, str]


def _validate_endpoint(url: str) -> None:
    target = urlsplit(url)
    if (
        target.scheme not in {"http", "https"}
        or not target.hostname
        or target.username is not None
        or "#" in url
        or "${" in url
        or not re.fullmatch(r"[!-~]+", url)
    ):
        raise ValueError("Invalid telemetry endpoint")
    # urlsplit validates the port number on access.
    _ = target.port


def _validate_headers(headers: dict[str, str]) -> None:
    names = set(_RESERVED)
    for name, template in headers.items():
        if name.lower() in names or not re.fullmatch(r"[A-Za-z0-9_-]+", name):
            raise ValueError("Invalid or duplicate telemetry header name")
        names.add(name.lower())
        if not re.fullmatch(r"[ -~]+", template) or "${" in SECRET_REFERENCE.sub("", template):
            raise ValueError("Invalid telemetry header template")


def _validate(options: TelemetryOptions) -> TelemetryOptions:
    url = options.get("endpoint")
    if url is not None:
        _validate_endpoint(url)
    _validate_headers(options.get("headers", {}))
    if options.get("enabled") and not url:
        raise ValueError("Enabled telemetry requires an endpoint")
    return options


type TelemetrySettings = Annotated[TelemetryOptions, AfterValidator(_validate)]


@with_config(ConfigDict(strict=True, extra="ignore"))
class ExportSettings(TypedDict, total=False):
    """Read the two export sections from a full factory configuration."""

    telemetry: TelemetrySettings
    logs: TelemetrySettings
