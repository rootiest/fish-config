# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# COMPONENT
#   aliases/shell-tools
#
# SYNOPSIS
#   bash [args...]
#
# DESCRIPTION
#   Switches the current shell session to bash, loading config from the XDG
#   config directory. Resets $SHELL back to fish on exit.
#
# ARGUMENTS
#   args...  Arguments passed through to the bash command
#
# EXAMPLE
#   bash
function bash --wraps='bash' --description 'bash switches to bash shell'
    # Opinionated guard (C1): fall back to bare command bash when disabled.
    if not __fish_config_op_enabled (status current-function)
        command bash $argv
        return $status
    end

    set SHELL $(which bash) # Set shell to bash
    command bash --rcfile "$XDG_CONFIG_HOME/bash/bashrc" $argv # Run bash
    set SHELL $(which fish) # Reset shell
end
