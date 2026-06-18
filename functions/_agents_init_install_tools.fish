# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_init_install_tools <agents_dir>
#
# DESCRIPTION
#   Copies the canonical version-bump script and git hook shims from
#   fish-config's scripts/agents-tools/ into <agents_dir>/.agents-tools/,
#   refreshing them when the shipped `agents-tools-version:` marker is newer
#   than the installed copy. Files are made executable. Idempotent: prints
#   nothing when the installed tooling is already current, or a short summary
#   line when it installed or updated the tooling.
#
# ARGUMENTS
#   agents_dir  Absolute path to the AGENTS/ sub-repo root
#
# RETURNS
#   0  Tooling is current or was installed/updated successfully
#   1  Canonical source missing or a copy failed
#
# EXAMPLE
#   set -l msg (_agents_init_install_tools /path/to/AGENTS)
#   test -n "$msg"; and echo $msg
function _agents_init_install_tools --argument-names agents_dir
    set -l src (path resolve (status dirname)/../scripts/agents-tools)
    test -d "$src"; or return 1
    set -l dest "$agents_dir/.agents-tools"

    set -l want (command grep -m1 -oE 'agents-tools-version: *[0-9]+' "$src/version-bump" 2>/dev/null | command grep -oE '[0-9]+$')
    set -l have ""
    test -f "$dest/version-bump"; and set have (command grep -m1 -oE 'agents-tools-version: *[0-9]+' "$dest/version-bump" 2>/dev/null | command grep -oE '[0-9]+$')

    test "$want" = "$have"; and return 0

    mkdir -p "$dest/hooks"; or return 1
    command cp "$src/version-bump" "$dest/version-bump"; or return 1
    command cp "$src/hooks/pre-commit" "$dest/hooks/pre-commit"; or return 1
    command cp "$src/hooks/prepare-commit-msg" "$dest/hooks/prepare-commit-msg"; or return 1
    chmod +x "$dest/version-bump" "$dest/hooks/pre-commit" "$dest/hooks/prepare-commit-msg"

    if test -z "$have"
        echo "→ Installed AGENTS/.agents-tools/ (version-bump v$want)"
    else
        echo "→ Updated AGENTS/.agents-tools/ (v$have → v$want)"
    end
end
