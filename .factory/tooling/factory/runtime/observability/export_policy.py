"""Decide whether this checkout may collect or deliver external traces and logs."""

import json
import sys
from functools import lru_cache
from pathlib import Path

from pydantic import TypeAdapter

from factory import file_reader
from factory.environment import settings
from factory.project.profile_io import parse_yaml
from factory.runtime.observability.configuration import ExportSettings, TelemetrySettings
from factory.runtime.workflow_core import relative

_POLICY = TypeAdapter[ExportSettings](ExportSettings)


@lru_cache(maxsize=1)
def _configured(raw: bytes) -> ExportSettings:
    data = parse_yaml(raw)
    if not isinstance(data, dict):
        raise ValueError("Invalid factory configuration")
    config = _POLICY.validate_python(data)
    if not config.get("telemetry", {}).get("enabled"):
        config.pop("telemetry", None)
    if not config.get("logs", {}).get("enabled"):
        config.pop("logs", None)
    return config


def development_install() -> bool:
    marker = Path(sys.prefix) / ".factory-ready.json"
    try:
        raw = file_reader.read_text(marker, encoding="utf-8")
    except FileNotFoundError:
        return False
    identity = json.loads(raw)
    return not isinstance(identity, dict) or identity.get("development") is not False


def active_settings(root: Path) -> ExportSettings:
    if settings().get("OTEL_SDK_DISABLED", "").lower() == "true" or development_install():
        return {}
    try:
        raw = file_reader.read_bytes(relative(root, ".factory/factory.yaml"))
    except FileNotFoundError:
        return {}
    return _configured(raw)


def enabled(root: Path) -> bool:
    """An invalid external receiver must never interrupt local work."""
    try:
        return "telemetry" in active_settings(root)
    except OSError, ValueError:
        return False


def logs_settings(root: Path) -> TelemetrySettings | None:
    """Decide eligibility at emission, and recheck before network delivery."""
    try:
        return active_settings(root).get("logs")
    except OSError, ValueError:
        return None
