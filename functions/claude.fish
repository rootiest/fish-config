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
#   claude [ARGS...]
#
# DESCRIPTION
#   Wrapper for the claude CLI that ensures the AGENTS/ sub-repository is
#   initialized and any agent-made changes are committed before launch.
#   Delegates all scaffold and commit logic to agents-init --quiet (full
#   setup), which ensures AGENTS/ is scaffolded and CLAUDE.md is symlinked
#   to AGENTS/AGENTS.md in the current project.
#   All arguments are forwarded verbatim to the real claude binary.
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases
#   (or the __fish_config_opinionated master), the command is passed through
#   to the real claude binary unchanged.
#
# ARGUMENTS
#   ARGS  Any arguments forwarded verbatim to the underlying claude binary
#
# EXIT STATUS
#   Exit status of the underlying claude binary
#
# EXAMPLE
#   claude
#   claude --resume
#   claude "Explain the recent changes"
function claude --wraps=claude --description 'claude wrapper: auto-links AGENTS.md as CLAUDE.md'
    if not __fish_config_op_enabled (status current-function)
        command claude $argv
        return $status
    end

    agents-init --quiet

    command claude $argv
end
