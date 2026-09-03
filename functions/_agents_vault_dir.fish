# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_vault_dir
#
# DESCRIPTION
#   Prints the agent memory vault root. Honors the universal variable
#   __fish_agent_vault_dir when set, otherwise
#   ${XDG_DATA_HOME:-$HOME/.local/share}/agent-vault.
#
#   The vault holds agy state as well as Claude state, so it is not nested
#   under either tool's directory; it is backed-up state rather than
#   configuration, hence XDG_DATA_HOME rather than XDG_CONFIG_HOME.
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The vault root path, one line on stdout.
#
# EXAMPLE
#   set -l vault (_agents_vault_dir)
function _agents_vault_dir
    if set -q __fish_agent_vault_dir; and test -n "$__fish_agent_vault_dir"
        printf '%s\n' "$__fish_agent_vault_dir"
        return 0
    end
    set -l base $XDG_DATA_HOME
    test -n "$base"; or set base "$HOME/.local/share"
    printf '%s\n' "$base/agent-vault"
end
