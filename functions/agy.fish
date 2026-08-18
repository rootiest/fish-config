# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# COMPONENT
#   aliases/dev-tools
#
# DEPENDENCIES
#   agents-init
#
# SYNOPSIS
#   agy [ARGS...]
#
# DESCRIPTION
#   Wrapper for the agy Antigravity AI CLI that ensures the AGENTS/
#   sub-repository is initialized and any agent-made changes are committed
#   before launch. Delegates all scaffold and commit logic to agents-init
#   --quiet (full setup), which ensures AGENTS/ is scaffolded and CLAUDE.md
#   is symlinked to AGENTS/AGENTS.md in the current project. Arguments are
#   forwarded verbatim to the real agy binary, except for -r/--resume which
#   are translated to -c/--continue.
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases
#   (or the __fish_config_opinionated master), the command is passed through
#   to the real agy binary unchanged.
#
# ARGUMENTS
#   ARGS  Arguments forwarded to the underlying agy binary (-r translates to -c)
#
# EXIT STATUS
#   Exit status of the underlying agy binary
#
# EXAMPLE
#   agy
#   agy --resume
#   agy -i "initial prompt"
#   agy models
function agy --wraps=agy --description 'agy wrapper: auto-initializes AGENTS/ sub-repo before launch'
    if not __fish_config_op_enabled (status current-function)
        command agy $argv
        return $status
    end

    agents-init --quiet

    for i in (seq (count $argv))
        if test "$argv[$i]" = "-r"
            set argv[$i] "-c"
        else if test "$argv[$i]" = "--resume"
            set argv[$i] "--continue"
        else if string match -q -- "--resume=*" "$argv[$i]"
            set argv[$i] (string replace -- "--resume=" "--continue=" "$argv[$i]")
        end
    end

    command agy $argv
end
