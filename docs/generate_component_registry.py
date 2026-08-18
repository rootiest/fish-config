#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate the committed opinionated-component registry.

Walks every `# COMPONENT` header in functions/*.fish, conf.d/*.fish, and
config.fish and writes conf.d/__fish_config_op_registry.fish, the fish
data file __fish_config_op_registry_lookup reads at shell startup.

Run manually (via __fish_config_op_registry_rebuild) after editing a
# COMPONENT header, and automatically as a pre-step in build-manual.py
before the manual is built.
"""

import sys
from pathlib import Path

import manualtools as mt

DOCS = Path(__file__).parent
REPO = DOCS.parent
OUTPUT = REPO / "conf.d" / "__fish_config_op_registry.fish"


def collect_components() -> dict[str, list[str]]:
    """Gather every `# COMPONENT` header across the whole repo.

    Concatenates raw component lines when the same identity appears in
    more than one source (e.g. functions/auto-pull.fish and
    conf.d/auto-pull.fish both self-identify as "auto-pull" at runtime,
    since the guard can only ever look up the bare status
    current-function/basename string) rather than letting one silently
    overwrite the other.
    """
    out: dict[str, list[str]] = {}
    for source in (
        mt.parse_components(REPO / "functions"),
        mt.parse_components(REPO / "conf.d"),
        mt.parse_component_file(REPO / "config.fish"),
    ):
        for identity, lines in source.items():
            out.setdefault(identity, []).extend(lines)
    return out


def build_registry(components: dict[str, list[str]]) -> tuple[dict[str, list[str]], list[str]]:
    """Turn {identity: [raw COMPONENT lines]} into ({"identity:site": [tags]}, warnings).

    A site with both always/on and always/off tagged is a contradiction:
    both are stripped and a warning is emitted, but generation continues
    -- any other real tag on that same site survives. A site whose
    effective tag set is empty after stripping produces no registry entry
    at all, which __fish_config_op_enabled already treats as always/on
    (fail-open) at guard time -- see spec §4.5.
    """
    registry: dict[str, list[str]] = {}
    warnings: list[str] = []
    for identity, raw_lines in components.items():
        by_site: dict[str, list[str]] = {}
        for site, tag in mt.parse_component_lines(raw_lines):
            by_site.setdefault(site, []).append(tag)
        for site, tags in by_site.items():
            if "always/on" in tags and "always/off" in tags:
                label = identity if not site else f"{identity}:{site}"
                warnings.append(
                    f"{label}: both always/on and always/off tagged; ignoring both"
                )
                tags = [t for t in tags if t not in ("always/on", "always/off")]
            if tags:
                registry[f"{identity}:{site}"] = list(dict.fromkeys(tags))
    return registry, warnings


def render(registry: dict[str, list[str]]) -> str:
    keys = sorted(registry)
    lines = [
        "# Copyright (C) 2026 Rootiest",
        "# SPDX-License-Identifier: AGPL-3.0-or-later",
        "#",
        "# GENERATED FILE --- do not edit by hand.",
        "# Regenerate with __fish_config_op_registry_rebuild after editing a",
        "# # COMPONENT header, or automatically via docs/build-manual.py.",
        "# Source: docs/generate_component_registry.py",
        "#",
        "# This file must be sourced before any other conf.d/*.fish file that",
        "# calls the opinionated guard. That currently holds only because fish's",
        "# glob-based conf.d loading happens to sort this filename first",
        "# alphabetically among the guard-calling files -- do not rename it",
        "# without preserving that ordering.",
        "",
    ]
    if not keys:
        lines.append("set -g __fish_config_op_registry_keys")
        lines.append("set -g __fish_config_op_registry_values")
        return "\n".join(lines) + "\n"

    quoted_keys = [f'"{k}"' for k in keys]
    lines.append("set -g __fish_config_op_registry_keys \\")
    lines += [f"    {k} \\" for k in quoted_keys[:-1]] + [f"    {quoted_keys[-1]}"]
    lines.append("")

    values = ['"' + " ".join(registry[k]) + '"' for k in keys]
    lines.append("set -g __fish_config_op_registry_values \\")
    lines += [f"    {v} \\" for v in values[:-1]] + [f"    {values[-1]}"]
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    components = collect_components()
    registry, warnings = build_registry(components)
    for w in warnings:
        print(f"  WARN  {w}", file=sys.stderr)
    OUTPUT.write_text(render(registry))
    print(f"wrote {OUTPUT} ({len(registry)} entries)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).parent))
    raise SystemExit(main())
