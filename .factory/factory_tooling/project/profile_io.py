"""Load local declarative profiles; resolve files and preserve exact provenance."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Callable, Iterable
from pathlib import Path
from typing import Any, Unpack, cast

import yaml

from factory_tooling.project.contracts import (
    AcceptedDocument,
    MaterialEntry,
    Policy,
    ProjectData,
    Rule,
    Selection,
    Snapshot,
)
from factory_tooling.project.profile_rules import (
    document_paths,
    fields,
    local_policy_files,
    relative,
    require,
    select_rules,
    strings,
    validate,
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fingerprint(value: object) -> str:
    return sha(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    )


def safe_path(root: str | Path, rel: str, *, exists: bool = True) -> Path:
    relative(rel)
    root = Path(root).resolve()
    file = root / rel
    require(file.resolve().is_relative_to(root), f"path escapes root: {rel}")
    require(
        not any(
            (root / Path(*Path(rel).parts[:i])).is_symlink()
            for i in range(1, len(Path(rel).parts) + 1)
        ),
        f"symlink path: {rel}",
    )
    if exists:
        require(file.is_file(), f"missing file: {rel}")
    return file


def parse_yaml(data: str | bytes) -> Any:
    class UniqueLoader(yaml.SafeLoader):
        pass

    def mapping(
        loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False
    ) -> dict[str, Any]:
        result = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if not (isinstance(key, str) and key not in result):
                raise ValueError("Project policy: " + f"duplicate/invalid YAML key: {key}")
            result[key] = loader.construct_object(value_node, deep=deep)
        return result

    UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
    try:
        return yaml.load(data, Loader=UniqueLoader)  # noqa: S506  # SafeLoader with duplicate-key rejection.
    except yaml.YAMLError as exc:
        raise ValueError(f"Project policy: invalid YAML: {exc}") from exc


def compose_profile(
    raw: str | bytes, read_definition: Callable[[str], str | bytes]
) -> tuple[ProjectData, list[str]]:
    """Resolve explicit definition files, then validate the combined policy.

    Reader owns storage (checkout, pinned snapshot or accepted Git tree).
    Bundles cannot include files or override unrelated profile fields.
    """
    data = parse_yaml(raw)
    if not (isinstance(data, dict)):
        raise ValueError("Project policy: " + "profile must be a mapping")
    paths = []
    for field, collection in [("gate_files", "gates"), ("decision_files", "decisions")]:
        if field not in data:
            continue
        require(collection not in data, f"choose {field} or inline {collection}, not both")
        selected = data.pop(field)
        strings(selected, field, empty=True)
        for rel in selected:
            relative(rel)
            require(rel not in paths, f"duplicate definition file: {rel}")
        entries = []
        for rel in selected:
            bundle = parse_yaml(read_definition(rel))
            fields(bundle, {collection}, f"{collection} file")
            if not (isinstance(bundle.get(collection), list) and bundle[collection]):
                raise ValueError(
                    "Project policy: " + f"definition file needs nonempty {collection}: {rel}"
                )
            entries.extend(bundle[collection])
        data[collection] = entries
        paths.extend(selected)
    return validate(data), paths


def profile_workspace(path: str | Path) -> Path:
    """Installed profiles belong to the nearest .agents directory's project."""
    path = Path(path).absolute()
    return next((p.parent for p in path.parents if p.name == ".factory"), path.parent)


def load_profile(
    path: str | Path, *, read_bytes: Callable[[Path], bytes] = Path.read_bytes
) -> Policy:
    """Read a profile, explicit gate/decision files and local rules once. Never run project code."""
    path = Path(path).absolute()
    require(not path.is_symlink(), "symlink profile")
    path = path.parent.resolve() / path.name
    workspace = profile_workspace(path).resolve()
    profile_root = str(path.parent.relative_to(workspace))
    raw = read_bytes(path)
    files = {str(path): sha(raw)}

    def read_definition(rel: str) -> bytes:
        file = safe_path(path.parent, rel)
        content = read_bytes(file)
        files[str(file)] = sha(content)
        return content

    data, _ = compose_profile(raw, read_definition)
    local_paths = local_policy_files(data, profile_root)
    for rel in local_paths:
        file = safe_path(path.parent, rel)
        if str(file) not in files:
            files[str(file)] = sha(read_bytes(file))
    composition = {
        "data": data,
        "files": {str(Path(p).relative_to(path.parent)): h for p, h in files.items()},
    }
    return {
        "data": data,
        "path": str(path),
        "workspace": str(workspace),
        "profile_root": profile_root,
        "files": files,
        "hash": fingerprint(composition),
    }


def selected_materials(
    policy: Policy, workspace: str | Path, **selection: Unpack[Selection]
) -> list[tuple[Path, Rule]]:
    root = Path(policy["path"]).parent
    data = policy["data"]
    result = []
    for rule in select_rules(data, **selection):
        if "file" in rule:
            file = safe_path(root, rule["file"])
            result.append((file, rule))
        else:
            result.extend((safe_path(workspace, rel), rule) for rel in document_paths(data, rule))
    return result


def material_entries(
    policy: Policy,
    workspace: str | Path,
    *,
    read_bytes: Callable[[Path], bytes] = Path.read_bytes,
    **selection: Unpack[Selection],
) -> list[MaterialEntry]:
    """One read per file, all selection reasons retained; rule scope stays local."""
    entries: dict[str, MaterialEntry] = {}
    for file, rule in selected_materials(policy, workspace, **selection):
        key = str(file)
        if key not in entries:
            raw = read_bytes(file)
            entries[key] = {
                "path": key,
                "content": raw.decode("utf-8"),
                "sha256": sha(raw),
                "reason": "project profile",
                "audience": selection["audience"],
                "rules": [],
            }
        entries[key]["rules"].append(
            cast(Rule, {k: rule[k] for k in ("id", "for", "usage") if k in rule})
        )
    return list(entries.values())


def freeze_materials(
    policy: Policy, workspace: str | Path, selections: Iterable[Selection]
) -> dict[str, str]:
    """Freeze normative inputs only; ordinary reference docs may be updated."""
    result = {}
    for selection in selections:
        for file, rule in selected_materials(policy, workspace, **selection):
            if rule.get("usage", "policy") == "policy" and str(file) not in result:
                result[str(file)] = sha(file.read_bytes())
    return result


def check_frozen(files: dict[str, str]) -> None:
    for path, expected in files.items():
        require(
            Path(path).is_file()
            and not Path(path).is_symlink()
            and sha(Path(path).read_bytes()) == expected,
            f"policy drift: {path}",
        )


def snapshot(
    policy: Policy, *, source: str, documents: dict[str, AcceptedDocument] | None = None
) -> Snapshot:
    """Portable review snapshot. Source is the coordinator's pinned policy baseline."""
    if not (isinstance(source, str) and source.strip()):
        raise ValueError("Project policy: " + "snapshot needs baseline provenance")
    contents: dict[str, str] = {}
    for p, expected in policy["files"].items():
        raw = Path(p).read_bytes()
        require(sha(raw) == expected, "policy changed while capturing snapshot")
        contents[str(Path(p).relative_to(Path(policy["path"]).parent))] = raw.decode("utf-8")
    value = {
        "profile": policy["data"],
        "manifest": Path(policy["path"]).name,
        "source": source,
        "contents": contents,
        "documents": documents or {},
        "files": {
            str(Path(p).relative_to(Path(policy["path"]).parent)): h
            for p, h in policy["files"].items()
        },
    }
    value["profile_root"] = policy["profile_root"]
    return cast(Snapshot, value | {"sha256": fingerprint(value)})


def validate_snapshot(value: Any) -> ProjectData:
    if not (
        isinstance(value, dict)
        and set(value)
        == {
            "profile_root",
            "profile",
            "manifest",
            "source",
            "files",
            "contents",
            "documents",
            "sha256",
        }
    ):
        raise ValueError(
            "Project policy: "
            + "missing/invalid pinned project_policy; capture accepted baseline before review"
        )
    require(
        value["sha256"] == fingerprint({k: v for k, v in value.items() if k != "sha256"}),
        "project_policy hash mismatch",
    )
    if not (isinstance(value["source"], str) and value["source"].strip()):
        raise ValueError("Project policy: " + "missing policy provenance")
    if not (isinstance(value["files"], dict) and value["files"]):
        raise ValueError("Project policy: " + "missing policy file hashes")
    for p, h in value["files"].items():
        relative(p)
        if not (isinstance(h, str) and len(h) == 64 and all(c in "0123456789abcdef" for c in h)):
            raise ValueError("Project policy: " + "invalid policy file hash")
    if not (isinstance(value["contents"], dict) and set(value["contents"]) == set(value["files"])):
        raise ValueError("Project policy: " + "policy content/file inventory mismatch")
    for p, content in value["contents"].items():
        if not (isinstance(content, str) and sha(content.encode("utf-8")) == value["files"][p]):
            raise ValueError("Project policy: " + f"policy content hash mismatch: {p}")
    if not (isinstance(value["manifest"], str) and value["manifest"] in value["contents"]):
        raise ValueError("Project policy: " + "missing profile manifest")

    def read_definition(rel: str) -> str:
        require(rel in value["contents"], f"missing pinned gate/decision file: {rel}")
        content = value["contents"][rel]
        if not isinstance(content, str):
            raise ValueError("Project policy: pinned definition must be text")
        return content

    composed, _ = compose_profile(value["contents"][value["manifest"]], read_definition)
    require(
        set(local_policy_files(composed, relative(value["profile_root"])))
        <= set(value["contents"]),
        "missing pinned local policy file",
    )
    require(composed == value["profile"], "parsed profile differs from pinned manifest bytes")
    if not (isinstance(value["documents"], dict)):
        raise ValueError("Project policy: " + "invalid pinned project documents")
    for p, doc in value["documents"].items():
        relative(p)
        if not (
            isinstance(doc, dict)
            and isinstance(doc.get("content"), str)
            and (sha(doc["content"].encode("utf-8")) == doc.get("sha256"))
        ):
            raise ValueError("Project policy: " + f"invalid pinned document: {p}")
    return validate(value["profile"])


def review_materials(
    value: Snapshot,
    factory_root: str | Path,
    workspace: str | Path,
    *,
    role: str | None = None,
    scope: list[str] | None = None,
    audience: str = "worker",
) -> list[MaterialEntry]:
    """Deliver accepted policy bytes even when candidate modifies its own rules."""
    data = validate_snapshot(value)
    rules = select_rules(data, process="code-review", audience=audience, role=role, scope=scope)
    entries: dict[str, MaterialEntry] = {}
    for rule in rules:
        local = rule.get("file")
        for rel in [local] if local else document_paths(data, rule):
            if local:
                require(rel in value["contents"], f"missing pinned rule: {rel}")
                content, digest = value["contents"][rel], value["files"][rel]
                # Paths locate provenance only; never read candidate bytes here.
                path = str(Path(factory_root) / "project" / rel)
            else:
                require(rel in value["documents"], f"missing pinned project document: {rel}")
                content, digest = (
                    value["documents"][rel]["content"],
                    value["documents"][rel]["sha256"],
                )
                path = str(Path(workspace) / rel)
            entry = entries.setdefault(
                path,
                dict(
                    path=path,
                    content=content,
                    sha256=digest,
                    reason="accepted review policy: " + value["source"],
                    audience="project",
                    rules=[],
                ),
            )
            entry["rules"].append(
                cast(Rule, {k: rule[k] for k in ("id", "for", "usage") if k in rule})
            )
    require("AGENTS.md" in value["documents"], "missing accepted AGENTS.md for review")
    agents_document = value["documents"]["AGENTS.md"]
    entries[str(Path(workspace) / "AGENTS.md")] = MaterialEntry(
        content=agents_document["content"],
        sha256=agents_document["sha256"],
        path=str(Path(workspace) / "AGENTS.md"),
        reason="accepted project instructions: " + value["source"],
        audience="project",
    )
    return list(entries.values())
