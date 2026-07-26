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

    `Synopsis:` lines are skipped: they restate the calling convention,
    which the card already shows as its title, so using one as the card
    description wastes the line.
    """
    for line in body.split("\n"):
        line = line.strip()
        if not line or line.startswith(("#", "```", "|", "-", "*", ">")):
            continue
        if line.startswith("Synopsis:"):
            continue
        m = SENTENCE_RE.match(line)
        return (m.group(1) if m else line)[:160]
    return ""


# Commands common enough in this manual that a block whose every line starts
# with one is certainly shell, not prose or a two-column reference table.
SHELL_HEADS = frozenset(
    """
    abbr alias apt bg bind brew builtin cargo cat cd chmod code command cp curl
    dnf echo end env exec export fg fish fisher for funcsave function git help
    if jobs kitty ls man math mkdir mv nvim npm pacman paru pip pip3 pkg printf
    python python3 rm set shutdown source string sudo switch systemctl test time
    tmux touch trash type wget wezterm while yay zellij zypper
    """.split()
)

SYNOPSIS_PREFIX = "Synopsis:"
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


def _render_para(para: list[str], entry_name: str | None, deeper: bool) -> str:
    """Render one paragraph of a former indented block.

    `deeper` marks paragraphs carrying their own extra indentation — nested
    option tables, whose alignment only survives inside a code block.
    """
    if not deeper:
        if _is_prose(para):
            return "\n".join(line.strip() for line in para)
        if _is_shell(para, entry_name):
            body = "\n".join(para)
            return f"```fish\n{body}\n```"
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
        synopsis = lines.pop(0)[len(SYNOPSIS_PREFIX) :].strip()
        out.append(f"```fish\n{synopsis}\n```")

    para: list[str] = []
    for line in lines + [""]:
        if line.strip():
            para.append(line)
            continue
        if para:
            deeper = any(line.startswith(" ") for line in para)
            out.append(_render_para(para, entry_name, deeper))
            para = []
    return "\n\n".join(chunk for chunk in out if chunk.strip())


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
        slug_dir = "reference"
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
        intro, entries = _split_entries(body)

        cards = []
        links = []
        for title, entry_body in entries:
            entry_slug = re.sub(r"[^\w-]+", "-", title.strip().lower()).strip("-")
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
