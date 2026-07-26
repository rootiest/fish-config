# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# SYNOPSIS
#   docker [subcommand] [args...]
#
# DESCRIPTION
#   Wrapper for docker that intercepts the ps subcommand and redirects it to
#   the dops function for enhanced container listing. All other subcommands are
#   passed through to the real docker binary.
#
# ARGUMENTS
#   subcommand  Docker subcommand (ps is redirected to dops)
#   args...     Arguments forwarded to docker or dops
#
# EXAMPLE
#   docker ps
function docker --description 'Execute docker'
    if test -n "$argv[1]"
        switch $argv[1]
            case ps
                dops $argv[2..-1]
            case '*'
                command docker $argv[1..-1]
        end
    end
end
