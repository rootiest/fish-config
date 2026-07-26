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

import yaml

import manualtools as mt

DOCS = Path(__file__).parent
MANUAL = DOCS / "manual"


def build_concat(root: Path) -> str:
    """Concatenate the manual into one ordered markdown document.

    Each file contributes `# {manTitle or title}` at a level matching its
    depth, and its body headings are demoted by the same amount.

    The root `index.md` (the LANDING page) may carry a `pandoc` key in its
    frontmatter — the original document's pandoc metadata block
    (title/section/header/date/author). If present, it is re-emitted
    verbatim as the leading `---`-fenced block, ahead of every heading.
    """
    chunks: list[str] = []
    index_fm, _ = mt.parse(root / "index.md")
    pandoc_meta = index_fm.get("pandoc")
    if pandoc_meta:
        header = yaml.safe_dump(pandoc_meta, sort_keys=False, allow_unicode=True).rstrip()
        chunks.append(f"---\n{header}\n---")
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
