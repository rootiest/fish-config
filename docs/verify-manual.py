#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Verification checks for the docs/manual SSOT pipeline."""

import importlib.util
import re
import sys
import tempfile
from pathlib import Path

import manualtools as mt

# docs/build-manual.py follows this repo's hyphenated CLI-script naming
# convention (matching verify-manual.py), which means it
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


def test_function_stubs_carry_no_entries():
    """Category files are stubs: entries come from functions/*.fish headers.

    An authored `##` entry here would be a second copy of a function's
    documentation — exactly the duplication the header-SSOT migration
    removed — and the generator would emit its own entry alongside it.
    """
    root = Path(__file__).parent / "manual" / "05-functions"
    for path in root.glob("*.md"):
        if path.name == "index.md":
            continue
        _, body = mt.parse(path)
        stray = [ln for ln in body.split("\n") if ln.startswith(("## ", "### "))]
        assert not stray, f"{path.name} has authored entries: {stray}"


def _parsed_functions() -> dict[str, dict[str, list[str]]]:
    return mt.parse_functions(Path(__file__).parent.parent / "functions")


def test_every_categorised_function_produces_one_entry():
    import build_manual

    functions = _parsed_functions()
    entries = build_manual.build_entries(functions)
    got = [name for names in entries.values() for name, _ in names]
    assert sorted(got) == sorted(functions), (
        f"entry/function mismatch: "
        f"{sorted(set(functions) ^ set(got))}"
    )
    assert len(got) == len(set(got)), "a function produced more than one entry"


def test_entries_carry_the_required_sections():
    missing = []
    for name, fn in _parsed_functions().items():
        absent = [s for s in ("SYNOPSIS", "DESCRIPTION", "EXAMPLE") if not fn.get(s)]
        if absent:
            missing.append(f"{name}: {', '.join(absent)}")
    assert not missing, "headers missing required sections:\n  " + "\n  ".join(missing)


def test_every_category_resolves_to_a_stub():
    root = Path(__file__).parent / "manual" / "05-functions"
    stubs = {p.stem for p in root.glob("*.md") if p.name != "index.md"}
    used = {}
    for name, fn in _parsed_functions().items():
        used.setdefault(" ".join(fn.get("CATEGORY", [])).strip(), []).append(name)
    unknown = {c: v for c, v in used.items() if c not in stubs}
    assert not unknown, f"# CATEGORY values with no stub: {unknown}"
    empty = sorted(stubs - set(used))
    assert not empty, f"category stubs generating zero entries: {empty}"


def test_dependencies_resolve():
    """Every declared # DEPENDENCIES name must be a real function or binary.

    Catches typos, and catches stale entries when a dependency is renamed
    or deleted. External binaries are accepted when some file in the tree
    guards them with `type -q`, which is this repo's convention.
    """
    repo = Path(__file__).parent.parent
    functions = _parsed_functions()
    known = {p.stem for p in (repo / "functions").glob("*.fish")} | set(functions)
    for path in list(repo.glob("conf.d/*.fish")) + list((repo / "functions").glob("*.fish")):
        known |= set(re.findall(r"type -q\s+(\S+)", path.read_text(encoding="utf-8")))
    dangling = []
    for name, fn in functions.items():
        for dep in (d for d in re.split(r"[,\s]+", " ".join(fn.get("DEPENDENCIES", []))) if d):
            if dep not in known:
                dangling.append(f"{name} -> {dep}")
    assert not dangling, "unresolvable # DEPENDENCIES:\n  " + "\n  ".join(dangling)


def warn_public_functions_without_category():
    """Warn — never fail — on a public function carrying no `# CATEGORY`.

    Bundled plugin and prompt internals will always lack one, so this
    cannot be a hard failure; a genuinely new user-facing function going
    undocumented still needs to be visible in CI output.
    """
    repo = Path(__file__).parent.parent
    documented = set(_parsed_functions())
    orphans = sorted(
        p.stem
        for p in (repo / "functions").glob("*.fish")
        if not p.stem.startswith("_")
        and p.stem not in documented
        and "# SYNOPSIS" in p.read_text(encoding="utf-8")
    )
    if orphans:
        print(f"  WARN  {len(orphans)} documented function(s) lack # CATEGORY:")
        print("        " + ", ".join(orphans))


def _without_section_5(text: str) -> str:
    """Drop `# 5. FUNCTIONS REFERENCE` through the start of section 6.

    Section 5 is generated from `functions/*.fish` headers, so it
    legitimately differs from the pre-migration snapshot. The round-trip
    guard covers the authored sections either side of it.
    """
    start = text.find("\n# 5. ")
    if start == -1:
        return text
    end = text.find("\n# 6. ", start)
    return text[:start] + (text[end:] if end != -1 else "")


def _normalise(text: str) -> str:
    """Collapse whitespace so only content differences survive."""
    lines = [ln.rstrip() for ln in text.strip().split("\n")]
    return "\n".join(ln for ln in lines if ln != "")


def test_concat_roundtrips_original():
    """The concat of manual/ must reproduce the original fish-config.md exactly.

    Section 5 is excluded: it is generated from `functions/*.fish` headers
    and so legitimately differs from the snapshot. This test guarded the
    *format* migration; the header-SSOT change is a *content* migration,
    covered instead by the structural checks above.

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
    got = _without_section_5(build_manual.build_concat(docs / "manual"))
    want = _without_section_5(original.read_text())
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


def test_site_build_produces_function_pages():
    import tempfile

    import build_manual

    docs = Path(__file__).parent
    with tempfile.TemporaryDirectory() as d:
        out = Path(d)
        sidebar = build_manual.build_site(docs / "manual", out)
        pages = list(out.rglob("*.md*"))
        assert (out / "index.md").exists() or (out / "index.mdx").exists(), "landing page missing"
        fn_pages = [p for p in pages if "reference" in p.parts and p.name != "index.mdx"]
        assert len(fn_pages) > 80, f"expected >80 function pages, got {len(fn_pages)}"
        assert not (out / "00-name.md").exists(), "site:false page was published"
        assert sidebar, "sidebar structure is empty"
        for page in pages:
            fm, _ = mt.parse(page)
            assert "manTitle" not in fm, f"{page.name} leaked manTitle into site output"
            assert "title" in fm, f"{page.name} has no title"


def test_prettify_splits_an_entry_block():
    """A man-page-style entry becomes fenced code, prose, and a table."""
    import build_manual

    body = "\n".join(
        [
            "    Synopsis:  rm [-e | args...]",
            "    Safe rm wrapper routing to trash:",
            "",
            "      (no args)   List current trash contents",
            "      -e/--empty  Empty the trash",
            "",
            "    Falls back to /usr/bin/rm when trash is unavailable.",
            "",
            "    Example:",
            "    rm file.txt           # moves to trash",
            "    rm -e                 # empty trash",
        ]
    )
    out = build_manual.prettify(body, "rm")

    assert '```fish title="Usage"\nrm [-e | args...]\n```' in out, (
        "synopsis was not fenced as fish with a Usage title"
    )
    assert '```fish title="Examples"\nrm file.txt' in out, (
        "examples were not fenced as fish with an Examples title"
    )
    assert out.count("```") == 4, f"expected exactly two fences, got:\n{out}"
    assert "\nSafe rm wrapper routing to trash:" in out, "description stayed indented"
    assert "| `(no args)` | List current trash contents |" in out, (
        "option table was not converted to a markdown table"
    )
    assert (
        "\nFalls back to /usr/bin/rm when trash is unavailable." in out
    ), "trailing prose stayed indented"


def test_as_table_converts_option_blocks():
    """A labelled, column-aligned block becomes a table; wrapped rows fold in."""
    import build_manual

    out = build_manual._as_table(
        [
            "Options:",
            "  -a/--aggressive  Also removes node_modules, logs,",
            "                   and IDE dirs",
            "  -d/--dry-run     Print what would be removed",
            "Pass neither to run interactively.",
        ]
    )
    assert out is not None, "a plain option table was rejected"
    assert out.splitlines()[0] == "Options:", "the label line was dropped"
    assert out.splitlines()[-1] == "Pass neither to run interactively.", (
        "the trailing sentence was dropped"
    )
    assert (
        "| `-a/--aggressive` | Also removes node_modules, logs, and IDE dirs |" in out
    ), "a wrapped description did not fold into the row above"


def test_as_table_escapes_pipes():
    """`|` splits table cells even inside a code span, so it must be escaped."""
    import build_manual

    out = build_manual._as_table(
        ["  -r/-R  Recurse into it", "  -e|-E  Empty it"]
    )
    assert out is not None and r"`-e\|-E`" in out, f"pipe was not escaped:\n{out}"


def test_as_table_rejects_non_tables():
    """Returning None is always safe, so every ambiguous shape must return it."""
    import build_manual

    cases = {
        "single row": ["  -f/--force  Force-delete unmerged branches too"],
        "numbered list": [
            "  1. git+cargo source build (fish shell itself)",
            "  2. cargo (Rust tools — gets latest crate version)",
        ],
        "misaligned rows": [
            "  -e/--empty  Empty the trash",
            "  -S/--secure Permanently delete (single space, not a column)",
        ],
        "synopsis continuation": [
            "           auto-pull add [PATH]",
            "           auto-pull status",
        ],
        "unlabelled head": [
            "Routes to the best tool by context.",
            "  --disk  force duf",
            "  --dir   force dust",
        ],
        "live markdown in prose column": [
            "  add     Register <PATH>'s git root",
            "  remove  Unregister by basename",
        ],
    }
    for label, para in cases.items():
        assert build_manual._as_table(para) is None, f"{label} was wrongly tabled"


def test_as_ruled_table_converts_header_rule_rows():
    """A header + dashed-rule + rows block (Component Reference style) tables."""
    import build_manual

    out = build_manual._as_ruled_table(
        [
            "Component               Requires",
            "─────────────────────────────────────────",
            "spwin                   Kitty or WezTerm",
            "hist                    fzf + wl-copy (Wayland clipboard)",
        ]
    )
    assert out is not None, "a header+rule+rows block was rejected"
    assert out.splitlines()[0] == "| Component | Requires |"
    assert "| `spwin` | Kitty or WezTerm |" in out


def test_as_ruled_table_converts_per_column_dash_rule():
    """RST-style rule (one dash run per column, gapped like the header) tables too."""
    import build_manual

    out = build_manual._as_ruled_table(
        [
            "Variable                        Disables",
            "------------------------------  ------------------------------------",
            "__fish_config_op_aliases        Command shadows and flag injection",
            "__fish_config_op_autoexec       Startup side-effects",
        ]
    )
    assert out is not None, "a per-column dashed rule was rejected"
    assert out.splitlines()[0] == "| Variable | Disables |"
    assert "| `__fish_config_op_aliases` | Command shadows and flag injection |" in out


def test_as_ruled_table_folds_wrapped_continuations():
    """A row that splits into one cell continues the previous row's last column."""
    import build_manual

    out = build_manual._as_ruled_table(
        [
            "Component               What it captures",
            "─────────────────────────────────────────",
            "Scrollback capture      Terminal output saved to:",
            "                        ~/.terminal_history/scrollback.log",
            "tmux pane capture       Streamed via pipe-pane",
        ]
    )
    assert out is not None
    assert (
        "| `Scrollback capture` | Terminal output saved to: ~/.terminal_history/scrollback.log |"
        in out
    ), "a wrapped continuation line did not fold into the row above"


def test_as_ruled_table_code_spans_angle_brackets_and_braces():
    """<placeholder> / brace-glob cells get backtick-protected, not rejected."""
    import build_manual

    out = build_manual._as_ruled_table(
        [
            "Component               What it captures",
            "─────────────────────────────────────────",
            "tmux pane capture       saved to tmux_<session>-w<win>.log",
            "Autopair                auto-close to (), [], {}",
        ]
    )
    assert out is not None, "angle brackets/braces caused the table to be rejected"
    assert "`saved to tmux_<session>-w<win>.log`" in out
    assert "`auto-close to (), [], {}`" in out


def test_as_ruled_table_rejects_ambiguous_columns():
    """A row with fewer delimited columns than the header is a source bug, not a guess."""
    import build_manual

    out = build_manual._as_ruled_table(
        [
            "Command    Active behavior             Disabled fallback",
            "─────────────────────────────────────────────────────────",
            "ls         eza -l -a --icons            system ls",
            "du         duf (disk overview) system du",
        ]
    )
    assert out is None, "an under-delimited row should fall back to a code block"


def test_prettify_leaves_reference_tables_alone():
    """Column-aligned blocks are data, not shell, and must not be fenced."""
    import build_manual

    table = "    XDG_CONFIG_HOME    ~/.config\n    XDG_CACHE_HOME     ~/.cache"
    assert "```" not in build_manual.prettify(table), "a reference table got fenced"

    binds = "    n / nv / neovim    nvim\n    e                  edit"
    assert "```" not in build_manual.prettify(binds), "an abbreviation table got fenced"

    shell = "    set -U __fish_user_dots_path /path/to/dots"
    assert "```fish" in build_manual.prettify(shell), "a shell block was not fenced"


def test_prettify_titles_paths_and_commented_examples():
    """A bare file path or a leading '# in x.fish' comment become a title."""
    import build_manual

    path = "    $__fish_user_dots_path/local.fish"
    assert '```fish title="local.fish"\n$__fish_user_dots_path/local.fish\n```' in (
        build_manual.prettify(path)
    ), "a bare file path was not titled"

    commented = "\n".join(
        ["    # in local.fish", "    set -gx SCROLLBACK_HISTORY_MAX_FILES 200"]
    )
    out = build_manual.prettify(commented)
    assert '```fish title="local.fish"\nset -gx SCROLLBACK_HISTORY_MAX_FILES 200\n```' in out, (
        f"a filename comment was not promoted to the fence title:\n{out}"
    )


def test_as_aside_converts_a_single_line_label():
    """A `LABEL: text` line becomes a titled <Aside> with the label's type."""
    import build_manual

    out = build_manual._as_aside(["TIP: Use `-h` on any function for its help text."])
    assert out == (
        '<Aside type="tip" title="Tip">\n'
        "Use `-h` on any function for its help text.\n"
        "</Aside>"
    ), f"unexpected aside output:\n{out}"


def test_as_aside_converts_a_label_and_list():
    """A label line immediately followed by a list becomes one aside body."""
    import build_manual

    out = build_manual._as_aside(
        [
            "NOTE:",
            "  - Command shadows react immediately.",
            "  - conf.d-level components take effect in new shells.",
        ]
    )
    assert out == (
        '<Aside type="note" title="Note">\n'
        "  - Command shadows react immediately.\n"
        "  - conf.d-level components take effect in new shells.\n"
        "</Aside>"
    ), f"unexpected aside output:\n{out}"


def test_as_aside_adds_icon_only_where_types_collide():
    """WARNING and CAUTION share the `caution` type; only WARNING gets an icon."""
    import build_manual

    warning = build_manual._as_aside(["WARNING: Deletes files permanently."])
    caution = build_manual._as_aside(["CAUTION: Slow on large trees."])
    assert 'icon="warning"' in warning, f"WARNING lost its icon override:\n{warning}"
    assert "icon=" not in caution, f"CAUTION should use its type's default icon:\n{caution}"


def test_as_aside_rejects_non_label_paragraphs():
    """Only the closed set of 7 labels triggers an aside; other WORD: prose does not."""
    import build_manual

    cases = {
        "Example prefix": ["Example:", "rm file.txt"],
        "sentence with a colon": ["Options: pass one of the flags below."],
        "lowercase label": ["note: this should not become an aside"],
    }
    for label, para in cases.items():
        assert build_manual._as_aside(para) is None, f"{label} was wrongly asided"


def test_prettify_flat_paragraphs_unchanged_when_not_labeled():
    """Restructuring prettify()'s loop to buffer flat lines must not alter output for ordinary prose."""
    import build_manual

    body = "\n".join(
        [
            "## Heading",
            "",
            "First line of a paragraph",
            "continued on a second line.",
            "",
            "A second paragraph.",
        ]
    )
    assert build_manual.prettify(body) == body, "flat prose was altered by the aside buffering"


def test_prettify_converts_a_flat_note_paragraph_to_an_aside():
    """A `NOTE:` paragraph surrounded by ordinary prose becomes an <Aside>, prose is untouched."""
    import build_manual

    body = "\n".join(
        [
            "## Heading",
            "",
            "Ordinary prose before.",
            "",
            "NOTE: Something worth calling out.",
            "",
            "Ordinary prose after.",
        ]
    )
    out = build_manual.prettify(body)
    assert "## Heading" in out
    assert "Ordinary prose before." in out
    assert "Ordinary prose after." in out
    assert (
        '<Aside type="note" title="Note">\nSomething worth calling out.\n</Aside>' in out
    ), f"note paragraph was not converted:\n{out}"


def test_as_file_tree_converts_a_box_drawing_tree():
    """A root path plus ├──/└── branches becomes a Starlight <FileTree>."""
    import build_manual

    para = [
        "$__fish_user_dots_path/",
        "├── secrets.fish   API keys, tokens, passwords, personal identifiers",
        "└── local.fish     Machine-specific paths, env vars, and sourcing secrets",
    ]
    out = build_manual._as_file_tree(para)
    assert out == (
        "<FileTree>\n"
        "- $__fish_user_dots_path/\n"
        "  - secrets.fish API keys, tokens, passwords, personal identifiers\n"
        "  - local.fish Machine-specific paths, env vars, and sourcing secrets\n"
        "</FileTree>"
    ), f"unexpected file tree output:\n{out}"


def test_as_file_tree_rejects_non_trees():
    """Returning None is always safe for anything that isn't a root+branches shape."""
    import build_manual

    cases = {
        "no root slash": ["$__fish_user_dots_path", "├── secrets.fish"],
        "single line": ["$__fish_user_dots_path/"],
        "non-branch second line": ["$__fish_user_dots_path/", "secrets.fish"],
    }
    for label, para in cases.items():
        assert build_manual._as_file_tree(para) is None, f"{label} was wrongly treed"


def test_as_file_tree_accepts_deeper_trees():
    """A tree with indented branch lines becomes a Starlight <FileTree> with nested markdown lists."""
    import build_manual

    para = [
        "~/proj/",
        "├── src/",
        "│   └── main.fish",
        "└── README.md",
    ]
    out = build_manual._as_file_tree(para)
    assert out == (
        "<FileTree>\n"
        "- ~/proj/\n"
        "  - src/\n"
        "    - main.fish\n"
        "  - README.md\n"
        "</FileTree>"
    ), f"unexpected file tree output:\n{out}"


def test_customization_notes_render_as_aside():
    """The real 07-customization NOTE paragraph converts to one intact <Aside>."""
    import build_manual

    path = Path(__file__).parent / "manual" / "07-customization.md"
    _, body = mt.parse(path)
    out = build_manual.prettify(body)
    assert out.count('<Aside type="note" title="Note">') >= 1, f"expected at least one Note aside:\n{out}"
    aside = out.split('<Aside type="note" title="Note">')[1].split("</Aside>")[0]
    assert aside.count("  - ") == 4, f"expected exactly 4 bullets inside the aside:\n{aside}"
    assert "- Command shadows (rm, cat, ls, ...) react immediately" in aside
    assert "- With aliases disabled, rm falls back to bare `command rm`" in aside
    assert "- Disabled integration commands (spwin, tab, split, hist, logs, upgrade)" in aside
    assert "- On CachyOS, the distro fish config's own aliases" in aside


def test_site_promotes_pages_with_asides_or_filetrees_to_mdx():
    """A page whose rendered content contains <Aside> or <FileTree> is written as .mdx."""
    import build_manual

    docs = Path(__file__).parent
    with tempfile.TemporaryDirectory() as d:
        out = Path(d)
        build_manual.build_site(docs / "manual", out)

        assert (out / "11-personalization.mdx").exists(), "FileTree page was not promoted to .mdx"
        assert not (out / "11-personalization.md").exists(), "old .md sibling was left behind"

        assert (out / "13-viewing-this-manual.mdx").exists(), "Aside page (NOTE) was not promoted to .mdx"

        assert (out / "07-customization.mdx").exists(), "Aside page (rewritten NOTE) was not promoted to .mdx"

        assert (out / "02-path-setup.mdx").exists(), "Aside page (NOTE) was not promoted to .mdx"

        assert (out / "03-key-bindings.md").exists(), "plain page was wrongly promoted to .mdx"
        assert not (out / "03-key-bindings.mdx").exists(), "plain page should stay .md"

        text = (out / "11-personalization.mdx").read_text()
        assert "FileTree" in text.split("from '@astrojs/starlight/components';")[0]

        text2 = (out / "13-viewing-this-manual.mdx").read_text()
        assert "Aside" in text2.split("from '@astrojs/starlight/components';")[0]


def test_prettify_is_site_only():
    """The SSOT keeps the indented form the man-page pipeline depends on."""
    import build_manual

    manual = Path(__file__).parent / "manual"
    forbidden = ("```", "<Aside", "<FileTree", ":::")
    for path in manual.rglob("*.md"):
        text = path.read_text()
        for marker in forbidden:
            assert marker not in text, (
                f"{path.name} contains {marker!r}: prettify must run at "
                "site-build time, never be written back to the SSOT"
            )


def test_sidebar_has_no_duplicate_functions_entry():
    """The functions group must not also list itself as one of its children."""
    import build_manual

    docs = Path(__file__).parent
    with tempfile.TemporaryDirectory() as d:
        sidebar = build_manual.build_site(docs / "manual", Path(d))

    groups = [e for e in sidebar if "items" in e]
    group = next((g for g in groups if g["label"] == "Functions Reference"), None)
    assert group is not None, "expected to find 'Functions Reference' sidebar group"
    labels = [item["label"] for item in group["items"]]
    assert group["label"] not in labels[1:], (
        f"'{group['label']}' is repeated inside its own group: {labels}"
    )
    assert labels[0] == "Categories", f"group should lead with Categories, got {labels[0]}"
    assert not any(
        "autogenerate" in item for item in group["items"]
    ), "categories should be listed explicitly, not autogenerated from slugs"
    assert len(labels) == 15, f"expected Overview + 14 categories, got {len(labels)}"


def test_exit_status_never_describes_stdout_content():
    """EXIT STATUS documents $status; stdout/printed content belongs in RETURNS.

    Regression guard for the RETURNS -> EXIT STATUS split: a row like
    "0  Patterns appended, or the requested content printed" re-introduces
    the exact ambiguity (exit code vs. printed output) the split exists to
    remove. A `--stdout`-style flag name is not itself an offense — only
    "stdout" used as a bare word (not part of a flag) counts.
    """
    offenders = []
    for name, fn in _parsed_functions().items():
        for line in fn.get("EXIT STATUS", []):
            if re.search(r"(?<!-)\bstdout\b|\bprinted\b", line, re.IGNORECASE):
                offenders.append(f"{name}: {line.strip()}")
    assert not offenders, "stdout/printed language leaked into EXIT STATUS:\n  " + "\n  ".join(
        offenders
    )


def test_returns_renders_after_exit_status():
    """When a function has both, Exit Status: must render before Returns:."""
    import build_manual

    fn = {
        "SYNOPSIS": ["thing"],
        "DESCRIPTION": ["Does a thing."],
        "EXIT STATUS": ["0  Always"],
        "RETURNS": ["The thing, printed to stdout"],
        "EXAMPLE": ["thing"],
    }
    out = build_manual.render_entry(fn, [])
    exit_pos = out.find("Exit Status:")
    returns_pos = out.find("Returns:")
    assert exit_pos != -1 and returns_pos != -1, f"missing a section head:\n{out}"
    assert exit_pos < returns_pos, f"Returns: rendered before Exit Status::\n{out}"


def test_site_avoids_reserved_dir():
    """No output directory may collide with a Cloudflare Pages reserved name.

    Pages treats a top-level `functions/` directory in the deploy output as
    Pages Functions (server-side handlers) and drops it from the static-asset
    upload. The build succeeds, wrangler reports success, and every page under
    it 404s in production while working perfectly under `astro preview` — so
    only a check on the emitted tree catches it.
    """
    import build_manual

    reserved = {"functions", "_worker.js", "_routes.json"}
    docs = Path(__file__).parent
    with tempfile.TemporaryDirectory() as d:
        out = Path(d)
        build_manual.build_site(docs / "manual", out)
        clashes = {p.name for p in out.iterdir()} & reserved
    assert not clashes, (
        f"site output has Cloudflare Pages reserved name(s): {sorted(clashes)} "
        "— these are silently excluded from the deployed assets"
    )


def test_parse_component_lines_default_and_named_sites():
    lines = [
        "aliases/filesystem",
        "site exit-plain: overrides/key-bindings",
        "site logging-guard: logging/terminal-capture",
        "",
        "  ",
    ]
    got = mt.parse_component_lines(lines)
    assert got == [
        ("", "aliases/filesystem"),
        ("exit-plain", "overrides/key-bindings"),
        ("logging-guard", "logging/terminal-capture"),
    ], f"unexpected parse: {got}"


def test_parse_components_includes_underscore_prefixed_and_uncategorised():
    """Unlike parse_functions, parse_components has no # CATEGORY gate and
    no underscore exclusion -- every guarded identity must be visible."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "__private_helper.fish").write_text(
            "# COMPONENT\n"
            "#   logging/terminal-capture\n"
            "function __private_helper\n"
            "end\n"
        )
        (root / "no_category.fish").write_text(
            "# COMPONENT\n"
            "#   aliases/filesystem\n"
            "#\n"
            "# SYNOPSIS\n"
            "#   no_category\n"
            "function no_category\n"
            "end\n"
        )
        got = mt.parse_components(root)
    assert got["__private_helper"] == ["logging/terminal-capture"]
    assert got["no_category"] == ["aliases/filesystem"]


def test_parse_components_resolves_multi_header_file_to_function_name():
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "multi.fish").write_text(
            "# COMPONENT\n"
            "#   aliases/filesystem\n"
            "function first_fn\n"
            "end\n"
            "\n"
            "# COMPONENT\n"
            "#   aliases/network\n"
            "function second_fn\n"
            "end\n"
        )
        got = mt.parse_components(root)
    assert got == {
        "first_fn": ["aliases/filesystem"],
        "second_fn": ["aliases/network"],
    }, f"unexpected resolution: {got}"


def test_parse_component_file_single_file():
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / "config.fish"
        path.write_text(
            "# COMPONENT\n"
            "#   site greeting-block: greeting/greeting-message\n"
        )
        got = mt.parse_component_file(path)
    assert got == {"config": ["site greeting-block: greeting/greeting-message"]}


def test_build_registry_strips_on_off_contradiction_with_warning():
    import generate_component_registry as gcr

    components = {"contradictory_fn": ["always/on", "always/off", "aliases/filesystem"]}
    registry, warnings = gcr.build_registry(components)
    assert registry["contradictory_fn:"] == ["aliases/filesystem"], (
        f"the non-contradictory tag should survive: {registry}"
    )
    assert len(warnings) == 1 and "contradictory_fn" in warnings[0]


def test_build_registry_drops_empty_effective_tag_sets():
    import generate_component_registry as gcr

    components = {"only_contradictory": ["always/on", "always/off"]}
    registry, warnings = gcr.build_registry(components)
    assert "only_contradictory:" not in registry, (
        "a site stripped down to nothing must produce no registry entry "
        "(fail-open: absence of an entry already means always/on at guard time)"
    )
    assert len(warnings) == 1


def test_build_registry_keeps_sites_independent():
    import generate_component_registry as gcr

    components = {
        "smart_exit": [
            "site exit-plain: overrides/key-bindings",
            "site logging-guard: logging/terminal-capture",
        ]
    }
    registry, warnings = gcr.build_registry(components)
    assert registry["smart_exit:exit-plain"] == ["overrides/key-bindings"]
    assert registry["smart_exit:logging-guard"] == ["logging/terminal-capture"]
    assert not warnings


def test_collect_components_merges_identity_collisions_across_sources():
    """functions/auto-pull.fish and conf.d/auto-pull.fish both self-identify
    as "auto-pull" at runtime -- the guard only ever has the bare
    status current-function/basename string to look up with -- so
    collect_components must concatenate their raw COMPONENT lines
    rather than letting conf.d's entry silently overwrite functions'."""
    import generate_component_registry as gcr

    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "functions").mkdir()
        (root / "conf.d").mkdir()
        (root / "functions" / "auto-pull.fish").write_text(
            "# COMPONENT\n"
            "#   autoexec/sync\n"
            "function auto-pull\n"
            "end\n"
        )
        (root / "conf.d" / "auto-pull.fish").write_text(
            "# COMPONENT\n"
            "#   autoexec/sync\n"
        )
        (root / "config.fish").write_text("")

        orig_repo = gcr.REPO
        try:
            gcr.REPO = root
            got = gcr.collect_components()
        finally:
            gcr.REPO = orig_repo

    assert got["auto-pull"] == ["autoexec/sync", "autoexec/sync"], (
        f"both sources' tags should survive the merge, not overwrite: {got}"
    )


def test_render_registry_is_valid_fish_and_round_trips():
    """Sourcing render()'s output must leave the two arrays in the exact
    shape __fish_config_op_registry_lookup expects -- checked via the real
    lookup helper (functions/__fish_config_op_registry_lookup.fish, Task
    2) rather than re-parsing the generated text by hand."""
    import subprocess

    import generate_component_registry as gcr

    registry = {
        "rm:": ["aliases/filesystem"],
        "smart_exit:exit-plain": ["overrides/key-bindings"],
    }
    text = gcr.render(registry)

    repo = Path(__file__).parent.parent
    proc = subprocess.run(
        [
            "fish", "-c",
            f"source {repo}/functions/__fish_config_op_registry_lookup.fish; "
            "source /dev/stdin; "
            "__fish_config_op_registry_lookup rm ''; echo status=$status",
        ],
        input=text,
        capture_output=True,
        text=True,
    )
    assert "aliases/filesystem" in proc.stdout, f"unexpected output: {proc.stdout!r} {proc.stderr!r}"
    assert "status=0" in proc.stdout, f"lookup did not report found: {proc.stdout!r}"


def test_build_manual_regenerates_registry_before_building():
    """docs/build-manual.py must regenerate the registry as a pre-step."""
    import build_manual

    assert hasattr(build_manual, "generate_component_registry"), (
        "build-manual.py must import generate_component_registry so its "
        "main() can be called as a pre-step before --site/--concat run"
    )


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
    warn_public_functions_without_category()
    print(f"\n{len(TESTS) - failed}/{len(TESTS)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).parent))
    raise SystemExit(main())
