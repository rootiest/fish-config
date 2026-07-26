#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Shared helpers for the docs/manual SSOT pipeline.

Frontmatter parsing, deterministic tree ordering, and heading level shifts.
Used by build-manual.py, split-manual.py, and verify-manual.py.
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
    return fm, text[end + 5 :].lstrip('\n').rstrip()


def serialize(fm: dict, body: str) -> str:
    """Render a frontmatter dict and body back into markdown text."""
    block = yaml.safe_dump(fm, sort_keys=False, allow_unicode=True).rstrip()
    return f"---\n{block}\n---\n\n{body.rstrip()}\n"


def shift_headings(body: str, by: int) -> str:
    """Add `by` levels to every ATX heading, ignoring fenced code blocks."""
    if by == 0:
        return body
    out, in_fence = [], False
    for line in body.split("\n"):
        if FENCE_RE.match(line):
            in_fence = not in_fence
        if not in_fence:
            line = HEADING_RE.sub(lambda m: "#" * (len(m.group(1)) + by) + m.group(2), line)
        out.append(line)
    return "\n".join(out)


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
