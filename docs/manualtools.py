#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Shared helpers for the docs/manual SSOT pipeline.

Frontmatter parsing, deterministic tree ordering, heading level shifts, and
the `functions/*.fish` comment-header parser that is the SSOT for Section 5.
Used by build-manual.py and verify-manual.py.
"""

import re
from pathlib import Path

import yaml

FENCE_RE = re.compile(r"^\s*(```|~~~)")
HEADING_RE = re.compile(r"^(#{1,6})(\s)")


def parse(path: Path) -> tuple[dict, str]:
    """Split a markdown file into (frontmatter dict, body text).

    Files without a leading `---` block yield an empty dict and the whole
    text as body. Body is returned with trailing whitespace stripped.
    """
    text = path.read_text()
    if not text.startswith("---\n"):
        return {}, text.rstrip()
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text.rstrip()
    fm = yaml.safe_load(text[4:end]) or {}
    return fm, text[end + 5 :].removeprefix("\n").rstrip()


def serialize(fm: dict, body: str) -> str:
    """Render a frontmatter dict and body back into markdown text."""
    block = yaml.safe_dump(fm, sort_keys=False, allow_unicode=True).rstrip()
    return f"---\n{block}\n---\n\n{body.rstrip()}\n"


def shift_headings(body: str, by: int) -> str:
    """Add `by` levels to every ATX heading, ignoring fenced code blocks.

    Negative values promote headings. Level is clamped to [1, 6].
    """
    if by == 0:
        return body
    out, in_fence = [], False
    for line in body.split("\n"):
        if FENCE_RE.match(line):
            in_fence = not in_fence
        if not in_fence:
            line = HEADING_RE.sub(
                lambda m: "#" * max(1, min(6, len(m.group(1)) + by)) + m.group(2), line
            )
        out.append(line)
    return "\n".join(out)


HEADER_LABEL = re.compile(r"^#\s+([A-Z][A-Z ]*[A-Z])\s*$")
FUNC_DEF = re.compile(r"^\s*function\s+(\S+)")
SECTIONS = (
    "CATEGORY",
    "DEPENDENCIES",
    "SYNOPSIS",
    "DESCRIPTION",
    "ARGUMENTS",
    "EXIT STATUS",
    "RETURNS",
    "EXAMPLE",
    "NOTES",
)


def _header_blocks(lines: list[str]) -> list[tuple[int, dict[str, list[str]]]]:
    """Find every man-page comment header in a file's lines.

    Yields (index of the line that ended the block, {LABEL: body lines}).
    Body lines keep any indentation deeper than the standard `#   ` prefix,
    which is what lets nested option tables survive into the rendered entry.
    Comment runs carrying no `# LABEL` line at all (the copyright preamble,
    ordinary inline comments) produce nothing.
    """
    out: list[tuple[int, dict[str, list[str]]]] = []
    cur: dict[str, list[str]] = {}
    label: str | None = None
    for i, line in enumerate(lines + [""]):
        if not line.startswith("#"):
            if cur:
                out.append((i, cur))
            cur, label = {}, None
            continue
        m = HEADER_LABEL.match(line)
        if m:
            label = m.group(1)
            cur.setdefault(label, [])
        elif label is not None:
            body = line[1:]
            cur[label].append(body[3:] if body.startswith("   ") else body.strip())
    return out


def _trailing_blanks(lines: list[str]) -> int:
    """Count the blank `#` separator lines closing a section."""
    n = 0
    while n < len(lines) and not lines[len(lines) - 1 - n].strip():
        n += 1
    return n


def parse_functions(root: Path) -> dict[str, dict[str, list[str]]]:
    """Parse the comment header above every documented public function.

    `root` is the repository's `functions/` directory. Returns
    `{name: {LABEL: [lines]}}`.

    `# CATEGORY` is the opt-in: a header without one produces no entry. That
    keeps bundled-plugin and prompt internals (`fish_prompt`, `sponge_filter_*`,
    `fisher`, …) out of the manual with no exclusion list to maintain.

    A file carrying exactly one header is associated with its own stem, so a
    `function` nested inside a `type -q` guard still resolves. Only files with
    several headers walk forward to the next `function` definition.
    """
    out: dict[str, dict[str, list[str]]] = {}
    for path in sorted(root.glob("*.fish")):
        lines = path.read_text(encoding="utf-8").split("\n")
        blocks = _header_blocks(lines)
        for end, sections in blocks:
            if len(blocks) == 1:
                name = path.stem
            else:
                after = (m.group(1) for ln in lines[end:] if (m := FUNC_DEF.match(ln)))
                name = next(after, path.stem)
            if name.startswith("_") or "CATEGORY" not in sections:
                continue
            out[name] = {
                k: v[: len(v) - _trailing_blanks(v)] for k, v in sections.items()
            }
    return out


def parse_abbreviations(root: Path) -> dict[str, list[dict]]:
    """Parse annotated abbreviations from conf.d/.

    Returns {category: [{"name": name, "desc": desc}, ...]}
    """
    out: dict[str, list[dict]] = {}
    for filename in ("abbr.fish", "tricks.fish", "puffer.fish"):
        path = root / filename
        if not path.exists():
            continue
        lines = path.read_text(encoding="utf-8").split("\n")
        category = None
        desc = None
        name_override = None
        for line in lines:
            line = line.strip()
            if line.startswith("# @category "):
                category = line[12:].strip()
            elif line.startswith("# @desc "):
                desc = line[8:].strip()
            elif line.startswith("# @name "):
                name_override = line[8:].strip()
            elif line.startswith("abbr -a ") or line.startswith("bind ") or line.startswith("alias "):
                if category and desc:
                    if name_override:
                        name = name_override
                    elif line.startswith("abbr -a "):
                        name = line[8:].strip().split()[0].strip("'\"")
                    elif line.startswith("alias "):
                        name = line[6:].strip().split('=')[0]
                    else:
                        name = "unknown"
                    # Only add if we haven't added this name to this category yet
                    if not any(a["name"] == name for a in out.setdefault(category, [])):
                        out[category].append({
                            "name": name,
                            "desc": desc
                        })
                category = None
                desc = None
                name_override = None
    return out


def _sort_key(entry: Path) -> tuple:
    """Order by sidebar.order when present, else by filename. Stable."""
    target = entry / "index.md" if entry.is_dir() else entry
    order = None
    if target.exists():
        fm, _ = parse(target)
        order = (fm.get("sidebar") or {}).get("order")
    return (order is None, order if order is not None else 0, entry.name)


def walk(root: Path, depth: int = 0) -> list[tuple[Path, int]]:
    """Return ordered (path, depth) pairs for every markdown file under root.

    A directory sorts at the position of its index.md and its children are
    emitted immediately afterwards at depth+1.
    """
    entries = [e for e in root.iterdir() if e.is_dir() or e.suffix == ".md"]
    result: list[tuple[Path, int]] = []
    for entry in sorted(entries, key=_sort_key):
        if entry.is_dir():
            index = entry / "index.md"
            if index.exists():
                result.append((index, depth))
            result.extend(walk(entry, depth + 1))
        elif entry.name != "index.md" or depth == 0:
            result.append((entry, depth))
    return result
