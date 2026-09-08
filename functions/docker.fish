# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# DEPENDENCIES
#   dops
#
# SYNOPSIS
#   docker [subcommand] [args...]
#
# DESCRIPTION
#   Wrapper for docker that intercepts the ps subcommand and redirects it to
#   the dops function for enhanced container listing. All other subcommands,
#   and a bare invocation with no subcommand, are passed through to the real
#   docker binary.
#
# ARGUMENTS
#   subcommand  Docker subcommand (ps is redirected to dops)
#   args...     Arguments forwarded to docker or dops
#
# EXIT STATUS
#   Exit status of dops (for ps), or of the real docker binary otherwise
#
# EXAMPLE
#   docker ps
#   docker
function docker --description 'Execute docker, redirecting ps to the enhanced dops listing'
    if test -z "$argv[1]"
        command docker
        return
    end

    switch $argv[1]
        case ps
            dops $argv[2..-1]
        case '*'
            command docker $argv[1..-1]
    end
end
