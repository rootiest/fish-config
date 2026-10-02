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
# CLASSIFICATION
#   bypasses-shadow(claude)
#
# SYNOPSIS
#   claude [ARGS...]
#
# DESCRIPTION
#   Wrapper for the claude CLI that ensures the AGENTS/ sub-repository is
#   initialized and any agent-made changes are committed before launch.
#   Delegates all scaffold and commit logic to agents-init --quiet (full
#   setup), which ensures AGENTS.md (root and every scoped subdirectory)
#   is symlinked into AGENTS/ in the current project. claude-code reads
#   AGENTS.md natively, so no CLAUDE.md is created or maintained.
#
#   Also syncs the host-scoped agent memory vault (agents-vault), which
#   tracks curated memory living outside the project tree. The vault
#   commits on launch but does not push; pushing happens from the Claude
#   Code SessionEnd hook or an explicit agents-vault --push.
#
#   All arguments are forwarded verbatim to the real claude binary.
#
#   When the C3 privacy override is active, DO_NOT_TRACK and
#   DISABLE_TELEMETRY are removed from the claude process environment
#   only. claude-code turns off feature-flag evaluation when either is
#   set, and Remote Control (/remote-control, --remote-control) is gated
#   on a feature flag, so the global opt-out otherwise disables it. This
#   applies even when the C1 wrapper behavior is disabled.
#
#   The commands claude runs still get the opt-out: the wrapper points
#   CLAUDE_CODE_SHELL_PREFIX at scripts/claude-shell-prefix, which puts
#   both variables back for every Bash tool command. An existing
#   CLAUDE_CODE_SHELL_PREFIX is left alone, and those commands then run
#   without the opt-out. Hooks and MCP servers are not covered by the
#   prefix and run without it either way.
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
function claude --wraps=claude --description 'claude wrapper: ensures AGENTS/ is scaffolded before launch'
    # Remote Control needs feature flags, which the C3 privacy vars disable
    set -l strip
    if __fish_config_op_enabled config.fish privacy
        set strip -u DO_NOT_TRACK -u DISABLE_TELEMETRY
        # ...but the commands claude runs should keep the opt-out
        set -q CLAUDE_CODE_SHELL_PREFIX
        or set -a strip CLAUDE_CODE_SHELL_PREFIX=$__fish_config_dir/scripts/claude-shell-prefix
    end

    if __fish_config_op_enabled (status current-function)
        agents-init --quiet
        agents-vault --quiet
    end

    env $strip claude $argv
end
