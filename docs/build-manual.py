#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate publishable artifacts from the docs/manual SSOT.

  --concat   one ordered markdown document for pandoc / config-help
  --site     Starlight content tree + sidebar.json
"""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

import manualtools as mt

DOCS = Path(__file__).parent
MANUAL = DOCS / "manual"
FUNCTIONS = DOCS.parent / "functions"
SLUG_DIR = "reference"


def _is_function_page(path: Path, root: Path) -> bool:
    """True for a Section 5 category stub (not its index)."""
    rel = path.relative_to(root)
    return bool(rel.parts) and rel.parts[0].endswith("-functions") and rel.name != "index.md"


def _entry_slug(title: str) -> str:
    """The site's page slug for an entry heading."""
    return re.sub(r"[^\w-]+", "-", title.strip().lower()).strip("-")


def _entry_link(name: str, functions: dict) -> str:
    """Link a dependency name to its entry page; plain code span if unknown."""
    fn = functions.get(name)
    if not fn:
        return f"`{name}`"
    category = re.sub(r"^\d+-", "", fn["CATEGORY"][0])
    return f"[`{name}`](/{SLUG_DIR}/{category}/{_entry_slug(name)}/)"


def _with_entries(body: str, path: Path, entries: dict) -> str:
    """Append this category's generated `## name` entries to its stub body."""
    generated = entries.get(path.stem, [])
    if not generated:
        return body
    blocks = [f"## {name}\n\n{entry}" for name, entry in generated]
    return "\n\n".join(([body] if body.strip() else []) + blocks)


def build_concat(root: Path) -> str:
    """Concatenate the manual into one ordered markdown document.

    Each file contributes `# {manTitle or title}` at a level matching its
    depth, and its body headings are demoted by the same amount.

    `root / "_pandoc.yml"` (if present) holds the original document's
    pandoc metadata block (title/section/header/date/author) as raw text,
    with no frontmatter fences and no Astro-visible frontmatter key. When
    present, its contents are re-emitted byte-for-byte as the leading
    `---`-fenced block, ahead of every heading.
    """
    entries = build_entries(mt.parse_functions(FUNCTIONS))
    chunks: list[str] = []
    pandoc_path = root / "_pandoc.yml"
    if pandoc_path.exists():
        raw = pandoc_path.read_text().rstrip("\n")
        chunks.append(f"---\n{raw}\n---")
    for path, depth in mt.walk(root):
        fm, body = mt.parse(path)
        if not fm.get("man", True):
            continue
        heading = fm.get("manTitle") or fm.get("title", path.stem)
        chunks.append("#" * (depth + 1) + " " + heading)
        if _is_function_page(path, root):
            body = _with_entries(body, path, entries)
        if body:
            chunks.append(mt.shift_headings(body, depth))
    return "\n\n".join(chunks) + "\n"


SENTENCE_RE = re.compile(r"^(.+?[.!?])(\s|$)", re.S)
PIPELINE_KEYS = ("man", "site", "manTitle", "helpKeywords")
JSX_ATTR_ESCAPES = (
    ("&", "&amp;"),
    ('"', "&quot;"),
    ("<", "&lt;"),
    ("{", "&#123;"),
)


def _jsx_attr_escape(value: str) -> str:
    """Escape a string for safe use inside a quoted JSX attribute value.

    `&` must go first so escaping later characters doesn't double-escape
    the ampersands it introduces. `"` closes the attribute early; `<` and
    `{` are otherwise-live MDX/JSX syntax that must not be interpreted.
    """
    for char, escape in JSX_ATTR_ESCAPES:
        value = value.replace(char, escape)
    return value


def _first_sentence(body: str) -> str:
    """Extract a one-line description from the start of an entry body.

    The `Synopsis:` block is skipped whole — label line plus its
    deeper-indented continuation lines. It restates the calling convention,
    which the card already shows as its title, so using one as the card
    description wastes the line.

    Source prose is hard-wrapped, so the leading paragraph is unwrapped
    before the sentence match — otherwise a card truncates at the first
    line break, mid-clause.
    """
    para: list[str] = []
    in_fence = False
    syn_indent: int | None = None
    for raw in body.split("\n"):
        line = raw.strip()
        indent = len(raw) - len(raw.lstrip())
        if syn_indent is not None:
            if line and indent <= syn_indent:
                syn_indent = None
            else:
                continue
        if line.startswith("```"):
            in_fence = not in_fence
            if para:
                break
            continue
        if in_fence:
            continue
        if not line or line.startswith(("#", "|", "-", "*", ">")):
            if para:
                break
            continue
        if line.startswith("Synopsis:"):
            syn_indent = indent
            continue
        para.append(line)
    if not para:
        return ""
    text = " ".join(para)
    m = SENTENCE_RE.match(text)
    return (m.group(1) if m else text)[:160]


# Commands common enough in this manual that a block whose every line starts
# with one is certainly shell, not prose or a two-column reference table.
SHELL_HEADS = frozenset(
    """
    abbr alias apt bg bind brew builtin cargo cat cd chmod code command cp curl
    dnf docker echo end env exec export fg fish fisher for funcsave function git help
    if jobs kitty ls man math mkdir mv nvim npm pacman paru pip pip3 pkg printf
    python python3 rm set shutdown source string sudo switch systemctl test time
    tmux touch trash type wget wezterm while yay zellij zypper
    """.split()
)

SYNOPSIS_PREFIX = "Synopsis:"
EXAMPLE_PREFIX = "Example:"
INDENT = "    "


def _is_prose(para: list[str]) -> bool:
    """True when a paragraph reads as sentences rather than as code or a table.

    Column-aligned reference tables are the main thing to keep out of a
    syntax-highlighted fence, and internal runs of two-or-more spaces are
    what distinguishes them from prose. `<` and `{` are excluded because
    the emitted paragraph is live markdown, where both would be parsed.
    """
    text = " ".join(para)
    if "<" in text or "{" in text:
        return False
    if not para or para[-1].rstrip()[-1:] not in ".:":
        return False
    return all(
        len(line.split()) >= 3 and "  " not in line.strip() for line in para
    )


def _is_shell(para: list[str], entry_name: str | None) -> bool:
    """True when every line of a paragraph looks like a shell command."""
    name_re = (
        re.compile(rf"(?<![\w-]){re.escape(entry_name)}(?![\w-])")
        if entry_name
        else None
    )
    for line in para:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if name_re and name_re.search(stripped):
            continue
        if stripped.split()[0].lstrip("$").rstrip(";") not in SHELL_HEADS:
            return False
    return True


# A lone indented line that's just a path ending in a known extension —
# e.g. pointing at where a file lives — reads better as a titled snippet
# than an unhighlighted grey slab.
PATH_LINE_RE = re.compile(r"^[~$][\w./{}-]*\.\w+$")

# A leading "# in local.fish" / "# local.fish" comment names the file an
# example belongs to; promote it to the fence title instead of leaving it
# as a literal comment inside the code.
FILENAME_COMMENT_RE = re.compile(r"^#\s*(?:in\s+)?([\w-]+\.\w+)\s*$")

CELL_SPLIT = re.compile(r"\s{2,}")

# A rule line under a header row — the "Component Reference" tables'
# authoring convention (header, dashes, data rows all at the same indent,
# no ":"-terminated label). Either one solid run of dashes, or (RST-style)
# one dash run per column, gapped the same way CELL_SPLIT splits cells.
RULE_CELL_RE = re.compile(r"^[─\-]{3,}$")


def _cell(text: str, code: bool) -> str:
    """Render one table cell. `|` must be escaped even inside a code span."""
    text = text.strip().replace("|", r"\|")
    return f"`{text}`" if code and text else text


def _as_table(para: list[str]) -> str | None:
    """Render an aligned two-column block as a markdown table, else None.

    Option and subcommand tables are the one thing in this manual that is
    genuinely tabular, and the indented-code fallback renders them as a grey
    slab. Everything else stays in that fallback: returning None is always
    safe, so every check here is free to be conservative.

    The rows must form one contiguous indented run, optionally introduced by
    a label line (`Options:`) and closed by a sentence. Lines indented deeper
    than the run are wrapped descriptions and fold into the row above.
    """
    starts = [i for i, ln in enumerate(para) if ln.startswith(" ")]
    if len(starts) < 2 or starts != list(range(starts[0], starts[-1] + 1)):
        return None
    head = para[: starts[0]]
    body = para[starts[0] : starts[-1] + 1]
    tail = para[starts[-1] + 1 :]
    if head and not head[-1].rstrip().endswith(":"):
        return None  # a head that isn't a label means mixed content

    indent = min(len(ln) - len(ln.lstrip()) for ln in body)
    rows: list[list[str]] = []
    for line in body:
        if len(line) - len(line.lstrip()) > indent and rows:
            rows[-1][1] += " " + line.strip()
            continue
        parts = CELL_SPLIT.split(line.strip(), 1)
        if len(parts) != 2 or not parts[1].strip():
            return None  # not column-aligned; a numbered list, or prose
        rows.append([parts[0], parts[1].strip()])
    if len(rows) < 2:
        return None
    if any("<" in value or "{" in value for _, value in rows):
        return None  # live markdown in the prose column

    out = [line.strip() for line in head]
    out += ["| | |", "|---|---|"]
    out += [f"| {_cell(k, True)} | {_cell(v, False)} |" for k, v in rows]
    out += [line.strip() for line in tail]
    return "\n".join(out)


def _as_ruled_table(para: list[str]) -> str | None:
    """Render a header + solid-rule + rows block as an N-column table, else None.

    This is the "Component Reference" tables' convention: header row, a
    dashed rule, then data rows at the same indent (no ":"-label, no extra
    nesting — the two things _as_table looks for). A row that splits into
    just one cell is a word-wrapped continuation of the row above; anything
    else that doesn't match the header's column count is a source alignment
    bug, so bail out to the code-block fallback rather than guess.
    """
    if len(para) < 4:
        return None
    rule_cells = CELL_SPLIT.split(para[1].strip())
    if not all(RULE_CELL_RE.match(cell) for cell in rule_cells):
        return None
    header = CELL_SPLIT.split(para[0].strip())
    n = len(header)
    if n < 2:
        return None
    rows: list[list[str]] = []
    for line in para[2:]:
        parts = CELL_SPLIT.split(line.strip(), n - 1)
        if len(parts) == n:
            rows.append(parts)
        elif len(parts) == 1 and rows:
            rows[-1][-1] += " " + parts[0].strip()
        else:
            return None
    if len(rows) < 2:
        return None

    # Unlike _as_table's prose column, these tables legitimately contain
    # placeholders like <session> or brace globs — code-span protects them
    # instead of rejecting the whole table.
    def cell(text: str, code: bool) -> str:
        return _cell(text, code or "<" in text or "{" in text)

    out = [f"| {' | '.join(header)} |", "|" + "|".join(["---"] * n) + "|"]
    for row in rows:
        cells = [cell(row[0], True)] + [cell(c, False) for c in row[1:]]
        out.append(f"| {' | '.join(cells)} |")
    return "\n".join(out)


def _render_para(para: list[str], entry_name: str | None, deeper: bool) -> str:
    """Render one paragraph of a former indented block.

    `deeper` marks paragraphs carrying their own extra indentation — nested
    option tables, whose alignment only survives inside a code block.
    """
    if not deeper:
        if _is_prose(para):
            return "\n".join(line.strip() for line in para)
        if len(para) == 1 and PATH_LINE_RE.match(para[0].strip()):
            path = para[0].strip()
            name = path.rsplit("/", 1)[-1]
            return f'```fish title="{name}"\n{path}\n```'
        if _is_shell(para, entry_name):
            body = para
            title = None
            m = FILENAME_COMMENT_RE.match(para[0].strip())
            if m:
                title, body = m.group(1), para[1:]
            info = f'fish title="{title}"' if title else "fish"
            return f"```{info}\n" + "\n".join(body) + "\n```"
    table = _as_ruled_table(para) or _as_table(para)
    if table is not None:
        return table
    return "\n".join(INDENT + line for line in para)


def _prettify_block(block: list[str], entry_name: str | None) -> str:
    """Convert one indented block into fenced code, prose, and tables.

    The manual is authored man-page style: every example, table, and
    description sits in a single 4-space-indented block, which renders on
    the site as one unhighlighted grey slab. Splitting a block into its
    paragraphs recovers the structure the indentation flattened.
    """
    lines = [line[len(INDENT) :] if line.startswith(INDENT) else line for line in block]

    out: list[str] = []
    if lines and lines[0].startswith(SYNOPSIS_PREFIX):
        synopsis = [lines.pop(0)[len(SYNOPSIS_PREFIX) :].strip()]
        # A multi-line synopsis is authored aligned under the first line;
        # keep the whole thing in one fence rather than orphaning the rest.
        while lines and lines[0].startswith(" "):
            synopsis.append(lines.pop(0).strip())
        # A "Usage" title (Starlight's filename-title convention, repurposed
        # as a label) makes the synopsis read as a snippet of the function
        # it documents rather than a bare command example.
        info = 'fish title="Usage"' if entry_name else "fish"
        out.append(f"```{info}\n" + "\n".join(synopsis) + "\n```")

    para: list[str] = []
    for line in lines + [""]:
        if line.strip():
            para.append(line)
            continue
        if para:
            if para[0].strip() == EXAMPLE_PREFIX:
                example = para[1:]
                if example and _is_shell(example, entry_name):
                    body = "\n".join(example)
                    out.append(f'```fish title="Examples"\n{body}\n```')
                else:
                    deeper = any(line.startswith(" ") for line in example)
                    out.append(_render_para(example, entry_name, deeper))
            else:
                deeper = any(line.startswith(" ") for line in para)
                out.append(_render_para(para, entry_name, deeper))
            para = []
    return "\n\n".join(chunk for chunk in out if chunk.strip())


ASIDE_LABELS: dict[str, tuple[str, str, str | None]] = {
    "NOTE": ("note", "Note", None),
    "IMPORTANT": ("note", "Important", "star"),
    "TIP": ("tip", "Tip", None),
    "HINT": ("tip", "Hint", "question-circle"),
    "WARNING": ("caution", "Warning", "warning"),
    "CAUTION": ("caution", "Caution", None),
    "DANGER": ("danger", "Danger", None),
}
ASIDE_RE = re.compile(rf"^({'|'.join(ASIDE_LABELS)}):\s*(.*)$")


def _as_aside(para: list[str]) -> str | None:
    """Render a `LABEL: ...` flat paragraph as a Starlight <Aside>, else None."""
    m = ASIDE_RE.match(para[0])
    if not m:
        return None
    label, rest = m.groups()
    aside_type, title, icon = ASIDE_LABELS[label]
    body = "\n".join(([rest] if rest else []) + para[1:])
    attrs = f'type="{aside_type}" title="{title}"'
    if icon:
        attrs += f' icon="{icon}"'
    return f"<Aside {attrs}>\n{body}\n</Aside>"


def prettify(body: str, entry_name: str | None = None) -> str:
    """Rewrite a body's indented code blocks for the website.

    Site-only: the man page and `config-help` keep reading the untouched
    SSOT, where the indented form is exactly what pandoc wants.
    """
    out: list[str] = []
    block: list[str] = []
    in_fence = False

    for line in body.split("\n"):
        if mt.FENCE_RE.match(line):
            in_fence = not in_fence
        if not in_fence and (line.startswith(INDENT) or (not line.strip() and block)):
            block.append(line)
            continue
        if block:
            while block and not block[-1].strip():
                block.pop()
            out.append(_prettify_block(block, entry_name))
            out.append("")
            block = []
        out.append(line)

    if block:
        while block and not block[-1].strip():
            block.pop()
        out.append(_prettify_block(block, entry_name))
    return "\n".join(out)


ENTRY_HEADS = {
    "ARGUMENTS": "Arguments:",
    "EXIT STATUS": "Exit Status:",
    "RETURNS": "Returns:",
    "NOTES": "Notes:",
}


def render_entry(fn: dict[str, list[str]], used_by: list[str], link=None) -> str:
    """Render one parsed function header as a manual entry body.

    Emits the same man-page shape Section 5 was authored in — one 4-space
    indented block opening with `Synopsis:` — so `prettify` keeps handling it
    for the site and pandoc keeps handling it for the man page, with no
    special case on either side.

    `link` maps a function name to its markdown link, or is None for the man
    page, where a URL in the middle of a sentence is noise.
    """
    out: list[str] = []
    syn = fn.get("SYNOPSIS", [])
    if syn:
        pad = " " * len(SYNOPSIS_PREFIX + "  ")
        out.append(f"{SYNOPSIS_PREFIX}  {syn[0]}")
        out += [pad + line for line in syn[1:]]
        out.append("")
    for line in fn.get("DESCRIPTION", []):
        out.append(line)
    for label, head in ENTRY_HEADS.items():
        body = fn.get(label)
        if not body:
            continue
        out += ["", head] + ["  " + line for line in body]
    if fn.get("EXAMPLE"):
        out += ["", EXAMPLE_PREFIX] + fn["EXAMPLE"]

    block = "\n".join((INDENT + line).rstrip() for line in out)

    def names(raw: list[str]) -> list[str]:
        return [n for n in re.split(r"[,\s]+", " ".join(raw)) if n]

    refs = []
    for label, values in (
        ("Dependencies", names(fn.get("DEPENDENCIES", []))),
        ("Used by", sorted(used_by)),
    ):
        if values:
            rendered = ", ".join(link(v) if link else f"`{v}`" for v in values)
            refs.append(f"**{label}:** {rendered}")
    if refs:
        block += "\n\n" + "\n\n".join(refs)
    return block


def build_entries(functions: dict[str, dict], link=None) -> dict[str, list[tuple[str, str]]]:
    """Group rendered entries by category stem, ordered by function name.

    The `Used by` reverse index is computed here in one pass rather than
    authored: a bidirectional link maintained by hand drifts the moment one
    side is edited.
    """
    used_by: dict[str, list[str]] = {}
    for name, fn in functions.items():
        for dep in re.split(r"[,\s]+", " ".join(fn.get("DEPENDENCIES", []))):
            if dep in functions:
                used_by.setdefault(dep, []).append(name)

    out: dict[str, list[tuple[str, str]]] = {}
    for name in sorted(functions):
        fn = functions[name]
        body = render_entry(fn, used_by.get(name, []), link)
        out.setdefault(fn["CATEGORY"][0], []).append((name, body))
    return out


def _page_fm(fm: dict) -> dict:
    """Strip pipeline-only keys from frontmatter destined for the site."""
    return {k: v for k, v in fm.items() if k not in PIPELINE_KEYS}


def _split_entries(body: str) -> tuple[str, list[tuple[str, str]]]:
    """Split a category body into (intro, [(entry title, entry body)]).

    Fence-aware: an H2-looking line (`## ...`) inside a fenced code block
    (tracked the same way as `manualtools.shift_headings`) is treated as
    ordinary body text, not an entry boundary.
    """
    lines = body.split("\n")
    heading_re = re.compile(r"^## (.+)$")
    boundaries: list[tuple[int, str]] = []
    in_fence = False
    for i, line in enumerate(lines):
        if mt.FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if not in_fence:
            m = heading_re.match(line)
            if m:
                boundaries.append((i, m.group(1)))

    if not boundaries:
        return body.strip(), []

    intro = "\n".join(lines[: boundaries[0][0]]).strip()
    entries = []
    for idx, (line_no, title) in enumerate(boundaries):
        start = line_no + 1
        end = boundaries[idx + 1][0] if idx + 1 < len(boundaries) else len(lines)
        # Strip newlines only: a bare .strip() would eat the leading
        # indentation of the entry's first line, detaching the `Synopsis:`
        # line from the indented block it opens.
        entry_body = "\n".join(lines[start:end]).strip("\n")
        entries.append((title.strip(), entry_body))
    return intro, entries


def build_site(root: Path, out: Path) -> list[dict]:
    """Write the Starlight content tree. Returns the sidebar structure."""
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    functions = mt.parse_functions(FUNCTIONS)
    entries = build_entries(functions, link=lambda n: _entry_link(n, functions))

    sidebar: list[dict] = []
    functions_group: dict = {}
    for path, _depth in mt.walk(root):
        fm, body = mt.parse(path)
        if not fm.get("site", True):
            continue

        rel = path.relative_to(root)
        is_function_dir = rel.parts and rel.parts[0].endswith("-functions")

        if not is_function_dir:
            target = out / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(mt.serialize(_page_fm(fm), prettify(body)))
            if rel.name != "index.md":
                sidebar.append({"label": fm["title"], "link": "/" + rel.stem + "/"})
            continue

        # Section 5: category index page keeps its slot; entries explode.
        #
        # Deliberately NOT "functions": Cloudflare Pages reserves a top-level
        # `functions/` directory in the deploy output for Pages Functions
        # (server-side handlers) and silently drops it from the static-asset
        # upload. The pages build fine and never arrive — every entry 404s in
        # production while working locally. test_site_avoids_reserved_dir
        # guards this.
        slug_dir = SLUG_DIR
        if rel.name == "index.md":
            target = out / slug_dir / "index.md"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(mt.serialize(_page_fm(fm), prettify(body)))
            # Built explicitly rather than by `autogenerate`, which labels
            # each group with its raw directory slug and republishes this
            # index as a child of the group it already titles.
            functions_group = {
                "label": fm["title"],
                "collapsed": True,
                "items": [{"label": "Overview", "link": f"/{slug_dir}/"}],
            }
            sidebar.append(functions_group)
            continue

        category = re.sub(r"^\d+-", "", rel.stem)
        cat_dir = out / slug_dir / category
        cat_dir.mkdir(parents=True, exist_ok=True)
        intro, page_entries = _split_entries(_with_entries(body, path, entries))

        cards = []
        links = []
        for title, entry_body in page_entries:
            entry_slug = _entry_slug(title)
            desc = _first_sentence(entry_body)
            entry_fm = {"title": title}
            if desc:
                entry_fm["description"] = desc
            (cat_dir / f"{entry_slug}.md").write_text(
                mt.serialize(entry_fm, prettify(entry_body, title.split()[0]))
            )
            href = f"/{slug_dir}/{category}/{entry_slug}/"
            links.append({"label": title, "link": href})
            safe_title = _jsx_attr_escape(title)
            safe_desc = _jsx_attr_escape(desc)
            cards.append(
                f'  <LinkCard title="{safe_title}" href="{href}"'
                + (f' description="{safe_desc}"' if desc else "")
                + " />"
            )

        overview = (
            "import { CardGrid, LinkCard } from '@astrojs/starlight/components';\n\n"
            + (f"{intro}\n\n" if intro else "")
            + "<CardGrid>\n"
            + "\n".join(cards)
            + "\n</CardGrid>\n"
        )
        (cat_dir / "index.mdx").write_text(mt.serialize(_page_fm(fm), overview))

        functions_group.setdefault("items", []).append(
            {
                "label": fm["title"],
                "collapsed": True,
                "items": [
                    {"label": "Overview", "link": f"/{slug_dir}/{category}/"},
                    *links,
                ],
            }
        )

    return sidebar


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--concat", action="store_true", help="emit the pandoc document")
    ap.add_argument("--site", action="store_true", help="emit the Starlight content tree")
    ap.add_argument("-o", "--output", type=Path, help="write to PATH instead of stdout")
    args = ap.parse_args()

    if not (args.concat or args.site):
        ap.error("nothing to do: pass --concat and/or --site")

    if args.site:
        src = DOCS / "site" / "src"
        out = src / "content" / "docs"
        sidebar = build_site(MANUAL, out)
        (src / "sidebar.json").write_text(json.dumps(sidebar, indent=2) + "\n")
        print(f"wrote site content to {out} ({len(sidebar)} sidebar entries)")

    if args.concat:
        text = build_concat(MANUAL)
        if args.output:
            args.output.write_text(text)
            print(f"wrote {args.output}")
        else:
            sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).parent))
    raise SystemExit(main())
