# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   claude [ARGS...]
#
# DESCRIPTION
#   Wrapper for the claude CLI that ensures CLAUDE.md exists before launch.
#   Both the current directory and the git project root are checked. When
#   CLAUDE.md is absent but AGENTS.md is present in a checked directory, a
#   relative symlink CLAUDE.md -> AGENTS.md is created automatically so that
#   Claude Code picks up shared agent instructions without duplicating the
#   file. All arguments are forwarded verbatim to the real claude binary.
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases
#   (or the __fish_config_opinionated master), the command is passed through
#   to the real claude binary unchanged.
#
# ARGUMENTS
#   ARGS  Any arguments forwarded verbatim to the underlying claude binary
#
# RETURNS
#   Exit status of the underlying claude binary
#
# EXAMPLE
#   claude
#   claude --resume
#   claude "Explain the recent changes"
function claude --wraps=claude --description 'claude wrapper: auto-links AGENTS.md as CLAUDE.md'
    if not __fish_config_op_enabled __fish_config_op_aliases
        command claude $argv
        return $status
    end

    set -l c_ok    (set_color green)
    set -l c_reset (set_color normal)

    # Build the list of directories to inspect: cwd always, git root when different.
    set -l check_dirs (pwd)
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$git_root" -a "$git_root" != (pwd)
        set check_dirs $check_dirs $git_root
    end

    # Anchor for relative display: git root when available, otherwise cwd.
    set -l anchor $git_root
    test -z "$anchor" && set anchor (pwd)

    for dir in $check_dirs
        if not test -e "$dir/CLAUDE.md"
            if test -f "$dir/AGENTS.md"
                ln -s AGENTS.md "$dir/CLAUDE.md"
                set -l prefix ""
                if test "$dir" != "$anchor"
                    set prefix (string replace "$anchor/" "" "$dir")/
                end
                set -l msg (string join "" "→ Linked " $prefix "CLAUDE.md → " $prefix "AGENTS.md")
                echo $c_ok$msg$c_reset >&2
            end
        end
    end

    command claude $argv
end
