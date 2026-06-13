# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_init_ensure_gitignore <root> <label> <pattern>...
#
# DESCRIPTION
#   Appends any patterns not already covered by the project's .gitignore.
#   Uses `git check-ignore` for accurate rule matching (catches wildcards
#   and parent-dir globs). Falls back to a plain string search when the
#   root is not a git repository. Leading `/` is stripped from each pattern
#   before the path-based check so root-anchored patterns (e.g. /AGENTS.md)
#   are matched correctly.
#
#   Missing patterns are written as a single labeled block:
#
#     #   ──────────────── Added by agents-init ──────────────────
#     #   <label>
#     <pattern>
#     #   ────────────────────────────────────────────────────────
#
# ARGUMENTS
#   root      Absolute path to the project root containing .gitignore
#   label     Short description used in the block comment header
#   pattern   One or more gitignore patterns to ensure are present
#
# RETURNS
#   0  All patterns already ignored or successfully appended
#   1  Could not write to .gitignore
#
# EXAMPLE
#   _agents_init_ensure_gitignore /home/user/myproject "agents-init" "AGENTS/" "/AGENTS.md"
function _agents_init_ensure_gitignore
    set -l c_ok    (set_color green)
    set -l c_reset (set_color normal)

    if test (count $argv) -lt 3
        echo (set_color red)"_agents_init_ensure_gitignore: requires <root> <label> <pattern>..."(set_color normal) >&2
        return 1
    end

    set -l root     $argv[1]
    set -l label    $argv[2]
    set -l patterns $argv[3..]
    set -l gitignore "$root/.gitignore"

    set -l in_git 0
    git -C "$root" rev-parse --git-dir >/dev/null 2>&1
    and set in_git 1

    # Collect patterns not already covered
    set -l missing
    for pattern in $patterns
        # Strip leading / so git check-ignore receives a repo-relative path,
        # not an absolute filesystem path (which it cannot match against rules).
        set -l check_path (string replace -r '^/' '' "$pattern")
        set -l already 0
        if test $in_git -eq 1
            git -C "$root" check-ignore -q --no-index "$check_path" 2>/dev/null
            and set already 1
        else if test -f "$gitignore"
            grep -qF "$pattern" "$gitignore"
            and set already 1
        end
        if test $already -eq 0
            set -a missing "$pattern"
        end
    end

    test (count $missing) -eq 0; and return 0

    # Write missing patterns as a labeled block
    set -l header "#   ──────────────── Added by agents-init ──────────────────"
    set -l footer "#   ────────────────────────────────────────────────────────"
    printf '\n%s\n#   %s\n' "$header" "$label" >>"$gitignore"
    for p in $missing
        printf '%s\n' "$p" >>"$gitignore"
    end
    printf '%s\n' "$footer" >>"$gitignore"

    echo "$c_ok→ Added "(count $missing)" pattern(s) to .gitignore$c_reset"
end
