# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# COMPONENT
#   aliases/dev-tools
#
# DEPENDENCIES
#   agents-init, agents-vault
#
# SYNOPSIS
#   agy [ARGS...]
#
# DESCRIPTION
#   Wrapper for the agy Antigravity AI CLI that ensures the AGENTS/
#   sub-repository is initialized and any agent-made changes are committed
#   before launch. Delegates all scaffold and commit logic to agents-init
#   --quiet (full setup), which ensures AGENTS/ is scaffolded and CLAUDE.md
#   is symlinked to AGENTS/AGENTS.md in the current project.
#
#   Also syncs the host-scoped agent memory vault (agents-vault). agy has
#   no session-end hook, so its memory is captured on the next launch
#   rather than at session end.
#
#   Arguments are forwarded verbatim to the real agy binary, except for
#   -r/--resume which use different syntax in agy than claude: bare
#   -r/--resume (no session id following) translate to -c/--continue
#   (resume most-recent session); -r/--resume given a session id (via
#   =id or a following bare word) translate to --conversation(=id)
#   (open that specific session).
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases
#   (or the __fish_config_opinionated master), the command is passed through
#   to the real agy binary unchanged.
#
# ARGUMENTS
#   ARGS  Arguments forwarded to the underlying agy binary (-r/--resume
#         translate to -c/--continue or --conversation, see DESCRIPTION)
#
# EXIT STATUS
#   Exit status of the underlying agy binary
#
# EXAMPLE
#   agy
#   agy --resume
#   agy --resume=5fffb251-2cd6-4cfe-8dac-b5e913a86db6
#   agy -i "initial prompt"
#   agy models
function agy --wraps=agy --description 'agy wrapper: auto-initializes AGENTS/ sub-repo before launch'
    if not __fish_config_op_enabled (status current-function)
        command agy $argv
        return $status
    end

    agents-init --quiet
    agents-vault --quiet

    for i in (seq (count $argv))
        switch "$argv[$i]"
            case -r --resume
                # Session id given as next bare word (not a flag) -> --conversation.
                # Nothing follows, or next word is a flag -> resume most-recent (-c/--continue).
                set -l next (math $i + 1)
                if test $next -le (count $argv); and not string match -q -- '-*' "$argv[$next]"
                    set argv[$i] --conversation
                else if test "$argv[$i]" = -r
                    set argv[$i] -c
                else
                    set argv[$i] --continue
                end
            case '-r=*'
                set argv[$i] (string replace -- '-r=' '--conversation=' "$argv[$i]")
            case '--resume=*'
                set argv[$i] (string replace -- '--resume=' '--conversation=' "$argv[$i]")
        end
    end

    command agy $argv
end
