#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate publishable artifacts from the docs/manual SSOT.

  --concat   one ordered markdown document for pandoc / config-help
  --site     Starlight content tree + sidebar.json
"""

import argparse
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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--concat", action="store_true", help="emit the pandoc document")
    ap.add_argument("-o", "--output", type=Path, help="write to PATH instead of stdout")
    args = ap.parse_args()

    if not args.concat:
        ap.error("nothing to do: pass --concat")

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
