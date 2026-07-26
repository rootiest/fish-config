#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""One-shot migration: docs/fish-config.md -> docs/manual/**.

Run once, verify with verify-manual.py, then delete this script.
"""

import re
import shutil
import sys
from pathlib import Path

import manualtools as mt

DOCS = Path(__file__).parent
SRC = DOCS / "fish-config.md"
OUT = DOCS / "manual"
INDEX = DOCS / "fish-config.index"

MAN_ONLY = {"NAME", "SYNOPSIS", "TABLE OF CONTENTS"}
LANDING = "DESCRIPTION"
FUNCTIONS_TITLE_RE = re.compile(r"^\d+\.\s+FUNCTIONS REFERENCE$", re.I)
NUM_PREFIX_RE = re.compile(r"^\d+(\.\d+)*\.?\s+")


def slugify(title: str) -> str:
    s = NUM_PREFIX_RE.sub("", title).lower()
    s = re.sub(r"[^\w\s-]", "", s)
    return re.sub(r"[\s_]+", "-", s).strip("-")


def display_title(heading: str) -> str:
    """Strip leading numbering and normalise SHOUTING to Title Case."""
    t = NUM_PREFIX_RE.sub("", heading).strip()
    return t.title() if t.isupper() else t


def load_keywords() -> dict[str, list[str]]:
    """Reverse fish-config.index into {heading text: [keywords]}."""
    mapping: dict[str, list[str]] = {}
    if not INDEX.exists():
        return mapping
    for line in INDEX.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        keyword, heading = line.split("=", 1)
        mapping.setdefault(heading.strip().lstrip("# ").strip(), []).append(keyword.strip())
    return mapping


def split_h1(text: str) -> list[tuple[str, str]]:
    parts = re.split(r"^# (.+)$", text, flags=re.MULTILINE)
    return [(parts[i].strip(), parts[i + 1].strip()) for i in range(1, len(parts), 2)]


def split_h2(body: str) -> tuple[str, list[tuple[str, str]]]:
    parts = re.split(r"^## (.+)$", body, flags=re.MULTILINE)
    intro = parts[0].strip()
    subs = [(parts[i].strip(), parts[i + 1].strip()) for i in range(1, len(parts), 2)]
    return intro, subs


def main() -> int:
    if not SRC.exists():
        print(f"error: {SRC} not found", file=sys.stderr)
        return 1
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    keywords = load_keywords()
    sections = split_h1(SRC.read_text())
    order = 0

    for heading, body in sections:
        kw = keywords.get(heading, [])
        if heading in MAN_ONLY:
            path = OUT / f"00-{slugify(heading)}.md"
            fm = {
                "title": display_title(heading),
                "manTitle": heading,
                "man": True,
                "site": False,
            }
            path.write_text(mt.serialize(fm, body))
            continue

        if heading == LANDING:
            fm = {
                "title": "Fish Shell Configuration",
                "description": "Reference manual for the rootiest fish configuration.",
                "manTitle": heading,
                "sidebar": {"order": 0},
            }
            if kw:
                fm["helpKeywords"] = kw
            (OUT / "index.md").write_text(mt.serialize(fm, body))
            continue

        order += 1
        if FUNCTIONS_TITLE_RE.match(heading):
            # Section 5 explodes into a directory of category files.
            d = OUT / f"{order:02d}-functions"
            d.mkdir()
            intro, subs = split_h2(body)
            fm = {
                "title": display_title(heading),
                "manTitle": heading,
                "sidebar": {"order": order},
            }
            if kw:
                fm["helpKeywords"] = kw
            (d / "index.md").write_text(mt.serialize(fm, intro))

            for i, (sub_heading, sub_body) in enumerate(subs, start=1):
                sub_fm = {
                    "title": display_title(sub_heading),
                    "manTitle": sub_heading,
                    "sidebar": {"order": i},
                }
                sub_kw = keywords.get(sub_heading, [])
                if sub_kw:
                    sub_fm["helpKeywords"] = sub_kw
                # H3 function entries -> H2 so --site can split on them.
                promoted = mt.shift_headings(sub_body, -1)
                (d / f"{i:02d}-{slugify(sub_heading)}.md").write_text(
                    mt.serialize(sub_fm, promoted)
                )
            continue

        fm = {
            "title": display_title(heading),
            "manTitle": heading,
            "sidebar": {"order": order},
        }
        if kw:
            fm["helpKeywords"] = kw
        (OUT / f"{order:02d}-{slugify(heading)}.md").write_text(mt.serialize(fm, body))

    count = sum(1 for _ in OUT.rglob("*.md"))
    print(f"wrote {count} files to {OUT}")
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).parent))
    raise SystemExit(main())
