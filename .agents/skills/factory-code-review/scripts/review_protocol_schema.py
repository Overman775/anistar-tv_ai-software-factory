"""Current Factory review schema, manifest, diff, evidence, and tool primitives."""

from __future__ import annotations

import hashlib
import json
import re
import shlex
from pathlib import Path, PurePosixPath
from typing import Any

SCHEMA_VERSION = "3"
LENSES = ("system-design", "runtime-safety", "verification-quality")
TOOL_IDS = ("static", "tests", "deps")
GATE_STATUSES = {"PASS", "FINDING", "NOT_APPLICABLE", "NOT_RUN"}
TOOL_STATUSES = {"PASS", "FAIL", "NOT_APPLICABLE", "NOT_RUN"}
SEVERITIES = {"critical", "high", "medium"}
CONFIDENCES = {"high", "medium"}
VERDICTS = {"APPROVE", "NEEDS_WORK", "RETHINK"}
IDENTITY_FIELDS = (
    "schema_version",
    "review_id",
    "mode",
    "base_sha",
    "head_sha",
    "scope_hash",
)

UNIVERSAL_GATES = {
    "system-design": ("SYS-INTENT", "SYS-BOUNDARIES", "SYS-CONTRACTS"),
    "runtime-safety": ("RUN-BEHAVIOR", "RUN-FAILURES", "RUN-SECURITY"),
    "verification-quality": ("VER-COVERAGE", "VER-TEST-QUALITY", "VER-CHANGE-SAFETY"),
}
# Route by AniStar ownership and bounded path tokens, never source contents or
# arbitrary substrings ("review" and Factory session contracts are not app UI/auth).
DART_PATH = r"^(?=(?:lib|infrastructure|test|integration_test)/)(?=.*\.dart$)"
DATA_PATH = re.compile(
    DART_PATH + r".*(?:/|_)(?:data|api|repositories|repository|mapping|mapper|dto|models?)"
    r"(?:/|_|\.dart$)"
)
CLIENT_PATH = re.compile(
    r"^(?:infrastructure/(?:anistar|networking)|test/infrastructure/(?:anistar|networking)"
    r"|test/mocks/(?:anistar|networking))/"
    r"|" + DART_PATH + r".*(?:/|_)(?:providers?|overrides|transport)(?:_|\.dart$)"
    r"|^(?:lib|test)/runner/"
    r"|^(?:lib|test)/app/app_container(?:_test)?\.dart$"
    r"|^docs/adr/(?:0004-use-riverpod-for-app-di|0009-single-anistar-client-and-dio"
    r"|0010-normalized-anistar-contract)\.md$"
)
SESSION_PATH = re.compile(
    r"^(?:infrastructure/(?:networking|storage)|test/infrastructure/(?:networking|storage)"
    r"|test/mocks/storage)/"
    r"|" + DART_PATH + r".*(?:/|_)(?:auth|session|cookie|cookies|mirror|mirrors|origin|storage)"
    r"(?:/|_|\.dart$)"
    r"|^env/"
    r"|^docs/(?:04_network_and_playback|specs/01_authentication|specs/05_mirrors"
    r"|specs/07_watched_episodes)\.md$"
)
PLAYER_PATH = re.compile(
    r"^(?:lib/packages/features|test/packages/features|test/mocks/features)/player/"
    r"|" + DART_PATH + r".*(?:/|_)(?:player|playback|hls)(?:/|_|\.dart$)"
    r"|^tool/e2e/media/"
    r"|^docs/(?:04_network_and_playback|specs/04_playback)\.md$"
)
UI_PATH = re.compile(
    r"^(?:lib/packages/ui_kit|test/packages/ui_kit|lib/app|test/app)/"
    r"|^(?:lib/packages/features|test/packages/features)/[^/]+/(?:presentation|goldens)/"
    r"|^(?:lib/packages/features|test/packages/features|test/mocks/features)/player/"
    r"|" + DART_PATH + r".*(?:/|_)(?:screen|widget|view|focus|motion|player)(?:_test)?\.dart$"
    r"|^integration_test/support/(?:remote_controls|mobile_controls)\.dart$"
    r"|^docs/(?:specs/(?:04_playback|06_tv_interaction|08_motion|10_mobile_interaction)"
    r"|adr/0008-youtube-tv-interaction-reference)\.md$"
)
PLATFORM_PATH = re.compile(
    r"^android/"
    r"|^(?:(?:infrastructure/[^/]+|lib/packages/ui_kit)/)?pubspec\.(?:yaml|lock)$"
    r"|^(?:build\.gradle(?:\.kts)?|settings\.gradle(?:\.kts)?"
    r"|libs\.versions\.toml|gradle\.properties|flutter_native_splash\.yaml)$"
    r"|^tool/quality/verify_android_apk(?:_test)?\.py$"
    r"|^scripts/(?:flutter_app|e2e(?:-tv|-mobile|-all|_live)?)\.sh$"
    r"|^tool/e2e/"
    r"|^(?:integration_test|tool/e2e)/README\.md$"
    r"|^docs/(?:melos_tooling|vcs_guidelines|adr/0006-android-direct-anistar)\.md$"
)
SDK_PATH = re.compile(
    r"^(?:(?:infrastructure/[^/]+|lib/packages/ui_kit)/)?pubspec\.(?:yaml|lock)$"
    r"|^(?:\.fvmrc|melos\.yaml)$"
    r"|^tool/(?:version/|quality/verify_sdk\.dart$)"
    r"|^scripts/(?:flutter_app|check|generate|e2e(?:-tv|-mobile|-all|_live)?)\.sh$"
    r"|^docs/(?:melos_tooling|vcs_guidelines)\.md$"
)
ASYNC_PATH = re.compile(
    DART_PATH + r".*(?:/|_)(?:bloc|cubit|providers?|controller|service|repositories|repository)"
    r"(?:/|_|\.dart$)"
)
CONDITIONAL_GATES = (
    ("SYS-DATA", "system-design", DATA_PATH),
    ("SYS-PLATFORM", "system-design", PLATFORM_PATH),
    ("SYS-CLIENT", "system-design", CLIENT_PATH),
    ("RUN-SESSION", "runtime-safety", SESSION_PATH),
    ("RUN-PLAYER", "runtime-safety", PLAYER_PATH),
    ("VER-SDK", "verification-quality", SDK_PATH),
    ("RUN-ASYNC", "runtime-safety", ASYNC_PATH),
    ("RUN-UI", "runtime-safety", UI_PATH),
    ("VER-UI", "verification-quality", UI_PATH),
    ("VER-PLATFORM", "verification-quality", PLATFORM_PATH),
)
REGISTRY_RULE_IDS = {
    "BLOCK-DYNAMIC",
    "BLOCK-PRINT",
    "BLOCK-IGNORE",
    "BLOCK-CROSS-FEATURE-IMPORT",
    "BLOCK-PRESENTATION-API",
    "BLOCK-REPOSITORY-CONTRACT",
    "POLICY-UNFINISHED-IMPLEMENTATION",
}


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: JSON object required")
    return value


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def canonical_scope_hash(manifest: dict[str, Any]) -> str:
    payload = {
        "mode": manifest.get("mode"),
        "target": manifest.get("target"),
        "base_sha": manifest.get("base_sha"),
        "head_sha": manifest.get("head_sha"),
        "scope_files": manifest.get("scope_files"),
        "diff_sha256": manifest.get("diff_sha256"),
    }
    if manifest.get("mode") == "feature":
        payload["source_sha256"] = manifest.get("source_sha256")
    return sha256_text(json.dumps(payload, sort_keys=True, separators=(",", ":")))


def valid_scope_path(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and str(path) == value


def feature_source_errors(manifest: dict[str, Any]) -> list[str]:
    scope = manifest.get("scope_files")
    hashes = manifest.get("source_sha256")
    if not isinstance(scope, list) or not isinstance(hashes, dict):
        return ["manifest: feature requires source_sha256 map"]
    if set(hashes) != set(scope):
        return ["manifest: feature source_sha256 keys must exactly equal scope_files"]
    errors: list[str] = []
    for path in scope:
        digest = hashes.get(path)
        if not re.fullmatch(r"[0-9a-f]{64}", str(digest or "")):
            errors.append(f"manifest: feature source_sha256 invalid for {path}")
            continue
        try:
            current = hashlib.sha256(Path(path).read_bytes()).hexdigest()
        except OSError:
            errors.append(f"manifest: feature source missing for {path}")
            continue
        if current != digest:
            errors.append(f"manifest: feature source bytes changed for {path}")
    return errors


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"manifest: schema_version must be {SCHEMA_VERSION}")
    for field in ("review_id", "target", "scope_hash"):
        if not isinstance(manifest.get(field), str) or not manifest[field]:
            errors.append(f"manifest: {field} must be nonempty")
    if manifest.get("mode") not in {"branch", "pr", "feature"}:
        errors.append("manifest: mode must be branch, pr, or feature")
    if not re.fullmatch(r"[0-9a-f]{40}", str(manifest.get("head_sha", ""))):
        errors.append("manifest: head_sha must be a full lowercase Git SHA")
    scope = manifest.get("scope_files")
    if (
        not isinstance(scope, list)
        or not scope
        or any(not valid_scope_path(path) for path in scope)
        or scope != sorted(set(scope))
    ):
        errors.append("manifest: scope_files must be nonempty, sorted, unique relative paths")
    mode = manifest.get("mode")
    if mode in {"branch", "pr"}:
        if not re.fullmatch(r"[0-9a-f]{40}", str(manifest.get("base_sha", ""))):
            errors.append(f"manifest: {mode} requires full base_sha")
        if not isinstance(manifest.get("diff_file"), str) or not manifest["diff_file"]:
            errors.append(f"manifest: {mode} requires diff_file")
        if not re.fullmatch(r"[0-9a-f]{64}", str(manifest.get("diff_sha256", ""))):
            errors.append(f"manifest: {mode} requires diff_sha256")
    elif mode == "feature":
        if manifest.get("base_sha") is not None:
            errors.append("manifest: feature requires null base_sha")
        if manifest.get("diff_file") is not None or manifest.get("diff_sha256") is not None:
            errors.append("manifest: feature forbids diff_file and diff_sha256")
        errors.extend(feature_source_errors(manifest))
    if mode in {"branch", "pr"} and manifest.get("source_sha256") not in (None, {}):
        errors.append("manifest: branch/PR source_sha256 must be absent or null")
    if manifest.get("scope_hash") != canonical_scope_hash(manifest):
        errors.append("manifest: scope_hash mismatch")
    return errors


def decode_git_path(value: str) -> str:
    output = bytearray()
    index = 0
    while index < len(value):
        escaped = value[index:index + 4]
        if len(escaped) == 4 and escaped[0] == "\\" and re.fullmatch(r"\\[0-7]{3}", escaped):
            output.append(int(escaped[1:], 8))
            index += 4
        else:
            output.extend(value[index].encode("utf-8"))
            index += 1
    return output.decode("utf-8")


def parse_diff(diff: str) -> dict[str, Any]:
    paths: list[str] = []
    added: set[tuple[str, int]] = set()
    deleted: set[tuple[str, int]] = set()
    binary: set[str] = set()
    current: str | None = None
    old_line: int | None = None
    new_line: int | None = None
    for line in diff.splitlines():
        if line.startswith("diff --git "):
            parts = shlex.split(line)
            if len(parts) != 4 or not parts[3].startswith("b/"):
                raise ValueError("diff: malformed file header")
            current = decode_git_path(parts[3][2:])
            paths.append(current)
            old_line = new_line = None
            continue
        if current is None:
            continue
        if line.startswith("Binary files ") or line == "GIT binary patch":
            binary.add(current)
            continue
        match = re.match(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        if match:
            old_line, new_line = int(match.group(1)), int(match.group(2))
            continue
        if old_line is None or new_line is None or line.startswith("\\ No newline"):
            continue
        if line.startswith("+"):
            added.add((current, new_line))
            new_line += 1
        elif line.startswith("-"):
            deleted.add((current, old_line))
            old_line += 1
        else:
            old_line += 1
            new_line += 1
    if len(paths) != len(set(paths)):
        raise ValueError("diff: duplicate file section")
    return {"paths": sorted(paths), "new": added, "old": deleted, "binary": binary}


def load_diff_context(manifest: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    if manifest.get("mode") == "feature":
        return {
            "paths": manifest.get("scope_files", []),
            "new": set(),
            "old": set(),
            "binary": set(),
            "feature_sources_valid": not feature_source_errors(manifest),
        }, []
    try:
        diff = Path(manifest["diff_file"]).read_text(encoding="utf-8")
        errors = []
        if sha256_text(diff) != manifest.get("diff_sha256"):
            errors.append("diff: sha256 mismatch")
        context = parse_diff(diff)
        if context["paths"] != manifest.get("scope_files"):
            errors.append("diff: paths do not equal manifest scope")
        if errors:
            return {"paths": [], "new": set(), "old": set(), "binary": set()}, errors
        return context, errors
    except (KeyError, OSError, UnicodeError, ValueError) as exc:
        return {"paths": [], "new": set(), "old": set(), "binary": set()}, [f"diff: {exc}"]


def identity_errors(value: dict[str, Any], manifest: dict[str, Any], label: str) -> list[str]:
    return [
        f"{label}: identity mismatch for {field}"
        for field in IDENTITY_FIELDS
        if value.get(field) != manifest.get(field)
    ]


def expected_gates(scope_files: list[str]) -> dict[str, list[str]]:
    result = {lens: list(gates) for lens, gates in UNIVERSAL_GATES.items()}
    for gate_id, lens, pattern in CONDITIONAL_GATES:
        if any(pattern.search(path) for path in scope_files):
            result[lens].append(gate_id)
    return {lens: sorted(gates) for lens, gates in result.items()}


def validate_evidence(
    evidence: Any,
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
) -> tuple[bool, str]:
    if not isinstance(evidence, dict):
        return False, "evidence must be object"
    kind = evidence.get("kind")
    if kind == "tool":
        tool_id = evidence.get("tool_id")
        index = evidence.get("command_index")
        if tool_id not in tool_commands or type(index) is not int or not 0 <= index < tool_commands[tool_id]:
            return False, "tool evidence points outside validated parent results"
        return True, ""
    path = evidence.get("path")
    if path not in manifest.get("scope_files", []):
        return False, "evidence path outside scope"
    if manifest.get("mode") == "feature" and not diff.get("feature_sources_valid", False):
        return False, "feature evidence invalid after source drift"
    if kind == "binary":
        if manifest.get("mode") == "feature":
            try:
                content = Path(path).read_bytes()
                is_binary = b"\x00" in content
                if not is_binary:
                    content.decode("utf-8")
            except UnicodeDecodeError:
                is_binary = True
            except OSError:
                is_binary = False
            if not is_binary:
                return False, "feature binary evidence does not resolve to binary content"
        if manifest.get("mode") != "feature" and path not in diff["binary"]:
            return False, "binary evidence has no matching diff section"
        return True, ""
    if kind != "source":
        return False, "unsupported evidence kind"
    line = evidence.get("line")
    side = evidence.get("side")
    if type(line) is not int or line <= 0 or side not in {"new", "old"}:
        return False, "source evidence requires positive line and side new|old"
    if manifest.get("mode") == "feature":
        try:
            source = Path(path)
            line_count = len(source.read_text(encoding="utf-8").splitlines())
        except (OSError, UnicodeError):
            line_count = 0
        if side != "new" or not source.is_file() or line > line_count:
            return False, "feature source evidence does not resolve"
    elif (path, line) not in diff[side]:
        return False, "source evidence does not resolve to changed diff line"
    return True, ""


def validate_tool_results(
    paths: list[Path],
    manifest: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], dict[str, int], list[str], list[str]]:
    results: dict[str, dict[str, Any]] = {}
    command_counts: dict[str, int] = {}
    errors: list[str] = []
    failures: list[str] = []
    for path in paths:
        try:
            value = load_object(path)
        except (OSError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{path}: {exc}")
            continue
        tool_id = value.get("tool_id")
        label = f"tool {tool_id}"
        local = identity_errors(value, manifest, label)
        if tool_id not in TOOL_IDS:
            local.append(f"{label}: unknown tool_id")
        elif tool_id in results:
            local.append(f"{label}: duplicate result")
        status = value.get("status")
        commands = value.get("commands")
        command_schema_valid = True
        if status not in TOOL_STATUSES:
            local.append(f"{label}: invalid status")
        if status in {"NOT_APPLICABLE", "NOT_RUN"}:
            if not isinstance(value.get("reason"), str) or not value["reason"]:
                local.append(f"{label}: {status} requires reason")
            if commands not in ([], None):
                local.append(f"{label}: {status} forbids command records")
            if status == "NOT_RUN":
                local.append(f"{label}: NOT_RUN")
        elif status in {"PASS", "FAIL"}:
            if not isinstance(commands, list) or not commands:
                local.append(f"{label}: completed result requires commands")
            else:
                exits: list[int] = []
                for index, command in enumerate(commands):
                    if not isinstance(command, dict):
                        local.append(f"{label}[{index}]: command must be object")
                        command_schema_valid = False
                        continue
                    argv, cwd, exit_code = command.get("argv"), command.get("cwd"), command.get("exit_code")
                    if not isinstance(argv, list) or not argv or any(not isinstance(x, str) or not x for x in argv):
                        local.append(f"{label}[{index}]: argv invalid")
                        command_schema_valid = False
                    if not isinstance(cwd, str) or not cwd:
                        local.append(f"{label}[{index}]: cwd invalid")
                        command_schema_valid = False
                    if type(exit_code) is not int:
                        local.append(f"{label}[{index}]: exit_code invalid")
                        command_schema_valid = False
                    else:
                        exits.append(exit_code)
                    if (
                        not isinstance(command.get("stdout_excerpt"), str)
                        or not isinstance(command.get("stderr_excerpt"), str)
                        or type(command.get("stdout_truncated")) is not bool
                        or type(command.get("stderr_truncated")) is not bool
                    ):
                        local.append(
                            f"{label}[{index}]: output excerpts/truncation flags required"
                        )
                        command_schema_valid = False
                derived = "FAIL" if any(code != 0 for code in exits) else "PASS"
                if exits and status != derived:
                    local.append(f"{label}: status {status} contradicts exit codes")
                if derived == "FAIL":
                    failures.append(str(tool_id))
        errors.extend(local)
        if tool_id in TOOL_IDS and tool_id not in results and not identity_errors(value, manifest, label):
            results[tool_id] = value
            if status in {"PASS", "FAIL"} and isinstance(commands, list) and command_schema_valid:
                command_counts[tool_id] = len(commands)
    errors.extend(f"tool {tool_id}: missing result" for tool_id in sorted(set(TOOL_IDS) - set(results)))
    return results, command_counts, errors, sorted(set(failures))
