# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_init_ensure_gitignore <root> <pattern>
#
# DESCRIPTION
#   Appends <pattern> to <root>/.gitignore if the path it describes is not
#   already covered by any existing ignore rule. Uses `git check-ignore` for
#   accurate rule matching (catches wildcards and parent-dir globs). Falls
#   back to a plain string search when the root is not a git repository.
#
# ARGUMENTS
#   root     Absolute path to the project root containing .gitignore
#   pattern  Path pattern to ensure is ignored (e.g. "AGENTS/", "CLAUDE.md")
#
# RETURNS
#   0  Pattern already ignored or successfully appended
#   1  Could not write to .gitignore
#
# EXAMPLE
#   _agents_init_ensure_gitignore /home/user/myproject "AGENTS/"
function _agents_init_ensure_gitignore
    set -l root    $argv[1]
    set -l pattern $argv[2]

    set -l c_ok    (set_color green)
    set -l c_reset (set_color normal)

    if test (count $argv) -lt 2
        echo (set_color red)"_agents_init_ensure_gitignore: requires <root> and <pattern>"(set_color normal) >&2
        return 1
    end

    set -l gitignore "$root/.gitignore"

    # Prefer git check-ignore (respects wildcards, parent globs, negations).
    # --no-index lets it evaluate non-existent paths.
    set -l already_ignored 0
    if test -d "$root/.git"
        git -C "$root" check-ignore -q --no-index "$pattern" 2>/dev/null
        and set already_ignored 1
    else if test -f "$gitignore"
        grep -qF "$pattern" "$gitignore"
        and set already_ignored 1
    end

    if test $already_ignored -eq 0
        if not echo "$pattern" >>"$gitignore"
            echo (set_color red)"Error: could not write to $gitignore"(set_color normal) >&2
            return 1
        end
        echo "$c_ok→ Added $pattern to .gitignore$c_reset"
    end
end
