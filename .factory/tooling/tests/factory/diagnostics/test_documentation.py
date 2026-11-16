"""Check shipped documentation links and selected executable examples offline."""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

from markdown_it import MarkdownIt

from factory.paths import FACTORY_ROOT
from factory.project.profile_io import load_profile

PARSER = MarkdownIt("commonmark", {"html": True})


class AnchorParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: set[str] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for key, value in attrs:
            if value and (key == "id" or (tag == "a" and key == "name")):
                self.ids.add(value)


def anchors(text: str, *, html: bool = False) -> set[str]:
    parser = AnchorParser()
    if html:
        parser.feed(text)
        return parser.ids
    tokens = PARSER.parse(text)
    counts: dict[str, int] = {}
    for index, token in enumerate(tokens):
        if token.type == "html_block":
            parser.feed(token.content)
        for child in token.children or []:
            if child.type == "html_inline":
                parser.feed(child.content)
        if token.type != "heading_open":
            continue
        inline = tokens[index + 1]
        title = "".join(
            child.content
            for child in inline.children or []
            if child.type in {"text", "code_inline"}
        )
        slug = re.sub(r"[^\w\- ]", "", title.lower()).replace(" ", "-")
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        candidate = f"{slug}-{count}" if count else slug
        while candidate in parser.ids:
            count += 1
            candidate = f"{slug}-{count}"
        counts[slug] = count + 1
        parser.ids.add(candidate)
    return parser.ids


def link_errors(root: Path, files: list[Path]) -> list[str]:
    errors = []
    root = root.resolve()
    for source in files:
        text = source.read_text(encoding="utf-8")
        for token in PARSER.parse(text):
            for child in token.children or []:
                if child.type not in {"link_open", "image"}:
                    continue
                link = str(child.attrGet("href" if child.type == "link_open" else "src") or "")
                parts = urlsplit(link)
                if parts.scheme or parts.netloc or not link:
                    continue
                target = (
                    (source.parent / unquote(parts.path)).resolve()
                    if parts.path
                    else source.resolve()
                )
                if not target.is_relative_to(root):
                    errors.append(f"{source}: escapes root: {link}")
                elif not target.exists():
                    errors.append(f"{source}: missing target: {link}")
                elif parts.fragment:
                    if not target.is_file() or target.suffix.lower() not in {
                        ".md",
                        ".html",
                        ".htm",
                    }:
                        errors.append(f"{source}: unsupported anchor target: {link}")
                    elif unquote(parts.fragment) not in anchors(
                        target.read_text(encoding="utf-8"), html=target.suffix.lower() != ".md"
                    ):
                        errors.append(f"{source}: missing anchor: {link}")
    return errors


class DocumentationTests(unittest.TestCase):
    def test_shipped_links(self) -> None:
        files = [FACTORY_ROOT / "tooling/README.md"]
        files += sorted((FACTORY_ROOT / "contracts").rglob("*.md"))
        files += sorted((FACTORY_ROOT / "project/rules").rglob("*.md"))
        for skill in sorted((FACTORY_ROOT / "skills").glob("factory-*")):
            files += sorted(skill.rglob("*.md"))
        self.assertTrue(files)
        self.assertEqual([], link_errors(FACTORY_ROOT.parent, files))

    def test_documented_dry_run_command(self) -> None:
        readme = (FACTORY_ROOT / "tooling/README.md").read_text(encoding="utf-8")
        tokens = PARSER.parse(readme)
        heading = next(
            i
            for i, token in enumerate(tokens)
            if token.type == "inline"
            and token.content == "Dry run without a project or model calls"
        )
        command = next(
            token.content
            for token in tokens[heading + 1 :]
            if token.type == "fence" and token.info == "bash"
        )
        args = shlex.split(command)
        self.assertEqual(
            args, ["sh", ".factory/tooling/bin/python.sh", "-B", ".factory/tooling/bin/dry_run.py"]
        )
        launcher = FACTORY_ROOT / "tooling/bin" / ("python.cmd" if os.name == "nt" else "python.sh")
        script = FACTORY_ROOT / "tooling/bin/dry_run.py"
        invocation = ([str(launcher)] if os.name == "nt" else ["sh", str(launcher)]) + [
            "-B",
            str(script),
        ]
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                invocation,
                cwd=directory,
                capture_output=True,
                text=True,
                encoding="utf-8",
                timeout=60,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["status"], "PASS")
        self.assertEqual(output["model_calls"], 0)
        self.assertEqual(len(output["checks"]), 7)

    def test_linked_yaml_profile(self) -> None:
        rules = FACTORY_ROOT / "skills/factory-project-configure/references/rules.md"
        link = next(
            child.attrGet("href")
            for token in PARSER.parse(rules.read_text(encoding="utf-8"))
            for child in token.children or []
            if child.type == "link_open"
            and str(child.attrGet("href") or "").endswith("project.example.yaml")
        )
        self.assertIsNotNone(link)
        profile = (rules.parent / str(link)).resolve()
        self.assertEqual(profile, FACTORY_ROOT / "project/project.example.yaml")
        self.assertTrue(load_profile(profile))

    def test_link_boundaries_and_anchors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            root = base / "src"
            root.mkdir()
            (base / "outside.md").write_text("# Outside\n", encoding="utf-8")
            source = root / "a.md"
            source.write_text(
                '[ok](#hello) [explicit](#custom) [web](https://example.com)\n\n# Hello\n<a id="custom"></a>\n',
                encoding="utf-8",
            )
            self.assertEqual([], link_errors(root, [source]))
            self.assertEqual({"a", "a-1", "a-2"}, anchors("# A\n# A-1\n# A\n"))
            source.write_text(
                '[bad](#missing) [escape](../outside.md) [fake](#fake) [comment](#comment) [data](#data)\n\n```html\n<a id="fake">\n```\n<!-- <a id="comment"> -->\n<div data-id="data"></div>\n',
                encoding="utf-8",
            )
            errors = link_errors(root, [source])
            self.assertEqual(5, len(errors))
            self.assertIn("missing anchor", errors[0])
            self.assertIn("escapes root", errors[1])
            (root / "page.html").write_text('<a name="legacy"></a>', encoding="utf-8")
            (root / "binary.bin").write_bytes(b"\xff")
            source.write_text("[html](page.html#legacy) [binary](binary.bin#x)\n", encoding="utf-8")
            errors = link_errors(root, [source])
            self.assertEqual(1, len(errors))
            self.assertIn("unsupported anchor target", errors[0])
