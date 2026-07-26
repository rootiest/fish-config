#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Verification checks for the docs/manual SSOT pipeline."""

import importlib.util
import sys
import tempfile
from pathlib import Path

import manualtools as mt

# docs/build-manual.py follows this repo's hyphenated CLI-script naming
# convention (matching split-manual.py, verify-manual.py), which means it
# cannot satisfy a plain `import build_manual` on its own — Python's import
# statement never treats a hyphen as an underscore. Load it explicitly under
# the name the tests expect and register it in sys.modules; every later
# `import build_manual` (including the one inside test_concat_roundtrips_
# original below) then finds the cached module instead of touching the path
# finder.
_build_manual_path = Path(__file__).parent / "build-manual.py"
_spec = importlib.util.spec_from_file_location("build_manual", _build_manual_path)
_build_manual = importlib.util.module_from_spec(_spec)
sys.modules["build_manual"] = _build_manual
_spec.loader.exec_module(_build_manual)


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


def _normalise(text: str) -> str:
    """Collapse whitespace so only content differences survive."""
    lines = [ln.rstrip() for ln in text.strip().split("\n")]
    return "\n".join(ln for ln in lines if ln != "")


def test_concat_roundtrips_original():
    """The concat of manual/ must reproduce the original fish-config.md exactly.

    Prefers docs/fish-config.md.orig (a snapshot of the pre-migration file)
    when present. Once that snapshot is deleted post-migration,
    docs/fish-config.md IS the concat output regenerated in Step 5, so
    falling back to it turns this into an idempotency regression check
    instead of going red for a missing file.

    The pass/fail decision is an exact (raw-text) comparison, not a
    whitespace-normalised one. Blank lines are load-bearing for pandoc
    (`blank_before_header` is on by default): losing them merges paragraphs
    and stops headings being headings, so a test that tolerated blank-line
    or line-joining drift would stay green while the man page silently
    broke. `_normalise` is used only afterwards, to build a readable diff.
    """
    import build_manual

    docs = Path(__file__).parent
    original = docs / "fish-config.md.orig"
    label = "original"
    if not original.exists():
        original = docs / "fish-config.md"
        label = "fish-config.md"
    got = build_manual.build_concat(docs / "manual")
    want = original.read_text()
    if got != want:
        norm_got = _normalise(got)
        norm_want = _normalise(want)
        if norm_got == norm_want:
            raise AssertionError(
                "concat differs from original only in whitespace/blank lines "
                "(exact comparison failed, normalised comparison passed) — "
                "blank lines are load-bearing for pandoc, this is a real regression"
            )
        import difflib

        diff = list(
            difflib.unified_diff(
                norm_want.split("\n"), norm_got.split("\n"), label, "concat", lineterm="", n=1
            )
        )[:40]
        raise AssertionError("concat differs from original:\n" + "\n".join(diff))


def test_every_index_keyword_resolves():
    """Every keyword in fish-config.index must match a heading in the concat."""
    import build_manual

    docs = Path(__file__).parent
    index = docs / "fish-config.index"
    if not index.exists():
        print("  SKIP  test_every_index_keyword_resolves (no index file)")
        return
    concat = build_manual.build_concat(docs / "manual")
    headings = {ln.strip() for ln in concat.split("\n") if ln.startswith("#")}
    missing = []
    for line in index.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        keyword, heading = line.split("=", 1)
        if heading.strip() not in headings:
            missing.append(f"{keyword.strip()} -> {heading.strip()}")
    assert not missing, "unresolvable index keywords:\n  " + "\n  ".join(missing)


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
