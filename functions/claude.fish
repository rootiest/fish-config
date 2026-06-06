# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   claude [args...]
#
# DESCRIPTION
#   Wrapper for the claude CLI that always injects --remote-control unless it
#   is already present in the argument list.
#
# ARGUMENTS
#   args...  Arguments passed through to the claude command
#
# EXAMPLE
#   claude "Refactor the auth module"
function claude --wraps='claude --remote-control' --description 'claude with --remote-control always enabled'
    if contains -- --remote-control $argv
        command claude $argv
    else
        command claude --remote-control $argv
    end
end
