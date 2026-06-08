#!/usr/bin/env python3
"""Split docs/fish-config.md into a multi-page Markdown wiki in docs/wiki/.

Index page:  docs/wiki/index.md   — DESCRIPTION intro + full ToC
Section pages: docs/wiki/<n>-<slug>.md  — one per numbered section,
               with a top-level nav bar linking to every other section.
"""

import re
import sys
from pathlib import Path

# Sections whose content is merged into the index intro.
INTRO_TITLES = {"NAME", "SYNOPSIS", "DESCRIPTION"}

# Sections that are skipped entirely (replaced by the generated ToC).
SKIP_TITLES = {"TABLE OF CONTENTS"}


def strip_front_matter(text: str) -> str:
    """Remove pandoc YAML front matter (--- ... ---) from the start."""
    if text.startswith("---"):
        end = text.index("\n---\n", 3) + 5
        return text[end:]
    return text


def slugify(title: str) -> str:
    """Convert a section title to a kebab-case filename slug."""
    s = title.lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_]+", "-", s).strip("-")
    return s


def build_nav(sections: list, current_filename: str | None = None) -> str:
    """Return a one-line navigation bar for a section page."""
    parts = ["[Index](index.md)"]
    for s in sections:
        label = s["title"].title()
        if s["filename"] == current_filename:
            parts.append(f"**{label}**")
        else:
            parts.append(f"[{label}]({s['filename']})")
    return "**Sections:** " + " | ".join(parts)


def build_full_toc(sections: list) -> str:
    """Return a Markdown ToC list for the index page."""
    lines = ["## Table of Contents", ""]
    for s in sections:
        lines.append(f"- [{s['title'].title()}]({s['filename']})")
    return "\n".join(lines)


def main() -> None:
    src = Path("docs/fish-config.md")
    out_dir = Path("docs/wiki")

    if not src.exists():
        print(f"error: {src} not found", file=sys.stderr)
        sys.exit(1)

    out_dir.mkdir(parents=True, exist_ok=True)

    text = strip_front_matter(src.read_text())

    # Split on level-1 headings; re.split keeps the delimiters.
    parts = re.split(r"^(# .+)$", text, flags=re.MULTILINE)
    # parts[0]       — text before first heading (empty after front-matter strip)
    # parts[1,3,…]   — headings
    # parts[2,4,…]   — body content after each heading

    raw_sections = []
    for i in range(1, len(parts), 2):
        heading = parts[i].strip()
        body = parts[i + 1] if i + 1 < len(parts) else ""
        title = heading[2:].strip()   # strip leading '# '
        raw_sections.append({"heading": heading, "title": title, "body": body})

    intro_parts = []
    numbered_sections = []
    for s in raw_sections:
        if s["title"] in INTRO_TITLES:
            if s["title"] == "DESCRIPTION":
                intro_parts.append(s["body"].strip())
        elif s["title"] in SKIP_TITLES:
            pass  # discard; ToC is auto-generated
        else:
            slug = slugify(s["title"])
            s["filename"] = f"{slug}.md"
            numbered_sections.append(s)

    # ── Write index.md ──────────────────────────────────────────────────────
    intro_body = "\n\n".join(intro_parts).rstrip()
    # Strip any trailing thematic break that the source adds before the ToC.
    intro_body = re.sub(r"\n+---\s*$", "", intro_body)
    toc = build_full_toc(numbered_sections)
    index_content = f"# Fish Shell Configuration\n\n{intro_body}\n\n---\n\n{toc}\n"
    (out_dir / "index.md").write_text(index_content)
    print("  wrote docs/wiki/index.md")

    # ── Write section pages ──────────────────────────────────────────────────
    for s in numbered_sections:
        nav = build_nav(numbered_sections, current_filename=s["filename"])
        page_content = (
            f"{s['heading']}\n\n"
            f"{nav}\n\n"
            f"---\n\n"
            f"{s['body'].strip()}\n"
        )
        (out_dir / s["filename"]).write_text(page_content)
        print(f"  wrote docs/wiki/{s['filename']}")


if __name__ == "__main__":
    main()
