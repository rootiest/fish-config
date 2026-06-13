# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   agy [ARGS...]
#
# DESCRIPTION
#   Wrapper for the agy Antigravity AI CLI that ensures the AGENTS/
#   sub-repository is initialized and any agent-made changes are committed
#   before launch. Delegates all scaffold and commit logic to agents-init
#   (full setup). All arguments are forwarded verbatim to the real agy binary.
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases
#   (or the __fish_config_opinionated master), the command is passed through
#   to the real agy binary unchanged.
#
# ARGUMENTS
#   ARGS  Any arguments forwarded verbatim to the underlying agy binary
#
# RETURNS
#   Exit status of the underlying agy binary
#
# EXAMPLE
#   agy
#   agy chat
#   agy resume
function agy --wraps=agy --description 'agy wrapper: auto-initializes AGENTS/ sub-repo before launch'
    if not __fish_config_op_enabled __fish_config_op_aliases
        command agy $argv
        return $status
    end

    agents-init --quiet

    command agy $argv
end
