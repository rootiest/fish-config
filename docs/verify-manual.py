#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Verification checks for the docs/manual SSOT pipeline."""

import sys
import tempfile
from pathlib import Path

import manualtools as mt


def test_parse_roundtrip():
    fm = {"title": "Git", "sidebar": {"order": 4}, "helpKeywords": ["git", "gi"]}
    body = "## gitig\n\nManages ignore files."
    text = mt.serialize(fm, body)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "t.md"
        p.write_text(text)
        got_fm, got_body = mt.parse(p)
    assert got_fm == fm, f"frontmatter mismatch: {got_fm!r}"
    assert got_body == body, f"body mismatch: {got_body!r}"


def test_parse_no_frontmatter():
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "t.md"
        p.write_text("# Plain\n\ntext\n")
        fm, body = mt.parse(p)
    assert fm == {}, f"expected empty frontmatter, got {fm!r}"
    assert body == "# Plain\n\ntext", f"body mismatch: {body!r}"


def test_shift_headings():
    body = "## a\n\ntext\n\n### b"
    assert mt.shift_headings(body, 1) == "### a\n\ntext\n\n#### b"


def test_shift_headings_skips_code_fences():
    body = "## a\n\n```\n# not a heading\n```\n\n## b"
    got = mt.shift_headings(body, 1)
    assert "# not a heading" in got, "code fence content was modified"
    assert got.startswith("### a"), f"heading not shifted: {got[:10]!r}"


def test_walk_orders_by_sidebar_order_then_filename():
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "b.md").write_text(mt.serialize({"title": "B", "sidebar": {"order": 1}}, ""))
        (root / "a.md").write_text(mt.serialize({"title": "A", "sidebar": {"order": 2}}, ""))
        (root / "c.md").write_text(mt.serialize({"title": "C"}, ""))
        got = [p.name for p, _ in mt.walk(root)]
    assert got == ["b.md", "a.md", "c.md"], f"wrong order: {got}"


def test_walk_nests_directory_after_its_index():
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "01-first.md").write_text(mt.serialize({"title": "First"}, ""))
        sub = root / "02-group"
        sub.mkdir()
        (sub / "index.md").write_text(mt.serialize({"title": "Group"}, ""))
        (sub / "01-child.md").write_text(mt.serialize({"title": "Child"}, ""))
        (root / "03-last.md").write_text(mt.serialize({"title": "Last"}, ""))
        got = [(p.name, depth) for p, depth in mt.walk(root)]
    expected = [
        ("01-first.md", 0),
        ("index.md", 0),
        ("01-child.md", 1),
        ("03-last.md", 0),
    ]
    assert got == expected, f"wrong nesting: {got}"


def test_parse_roundtrip_body_with_leading_blank_line():
    fm = {"title": "Test"}
    body = "\nContent starts after blank line."
    text = mt.serialize(fm, body)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "t.md"
        p.write_text(text)
        got_fm, got_body = mt.parse(p)
    assert got_fm == fm, f"frontmatter mismatch: {got_fm!r}"
    assert got_body == body, f"body mismatch: expected {body!r}, got {got_body!r}"


def test_manual_tree_exists():
    root = Path(__file__).parent / "manual"
    assert root.is_dir(), "docs/manual/ not generated"
    assert (root / "index.md").exists(), "docs/manual/index.md missing"
    fn = root / "05-functions"
    assert fn.is_dir(), "docs/manual/05-functions/ missing"
    cats = sorted(p.name for p in fn.glob("*.md") if p.name != "index.md")
    assert len(cats) == 14, f"expected 14 function categories, got {len(cats)}: {cats}"


def test_function_entries_promoted_to_h2():
    root = Path(__file__).parent / "manual" / "05-functions"
    for path in root.glob("*.md"):
        if path.name == "index.md":
            continue
        _, body = mt.parse(path)
        assert "\n### " not in f"\n{body}", f"{path.name} still has H3 entries"
        assert "\n## " in f"\n{body}", f"{path.name} has no H2 function entries"


TESTS = [v for k, v in sorted(globals().items()) if k.startswith("test_")]


def main() -> int:
    failed = 0
    for t in TESTS:
        try:
            t()
            print(f"  PASS  {t.__name__}")
        except AssertionError as e:
            print(f"  FAIL  {t.__name__}: {e}", file=sys.stderr)
            failed += 1
    print(f"\n{len(TESTS) - failed}/{len(TESTS)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).parent))
    raise SystemExit(main())
