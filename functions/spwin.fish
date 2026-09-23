# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# COMPONENT
#   integrations/window-mgmt
#
# DEPENDENCIES
#   kitty, wezterm
#
# SYNOPSIS
#   spwin [args...]
#
# DESCRIPTION
#   Spawns a new terminal OS window in Kitty (via spawn-window.sh if
#   present, otherwise kitty @ launch) or WezTerm (via wezterm cli spawn).
#
# ARGUMENTS
#   args...  Arguments forwarded to the spawn command
#
# EXIT STATUS
#   0  Window opened successfully
#   1  Not running inside Kitty or WezTerm
#
# EXAMPLE
#   spwin
function spwin --wraps='~/.config/kitty/spawn-window.sh' --description 'spawn window in kitty or wezterm'
    __fish_help_header (status current-function) $argv; and return 0

    # Opinionated guard (C4): integrations disabled
    if not __fish_config_op_enabled (status current-function)
        __fish_palette
        echo "$c_err"'spwin: disabled by __fish_config_op_integrations'"$c_reset" >&2
        return 1
    end

    # $TERM/$TERM_PROGRAM only prove the terminal type, not that its CLI
    # binary is on $PATH -- e.g. sshing out from Kitty/WezTerm inherits the
    # env var on the remote host without the binary. Check explicitly.
    if test "$TERM" = xterm-kitty
        if test -x ~/.config/kitty/spawn-window.sh
            ~/.config/kitty/spawn-window.sh $argv
        else if type -q kitty
            kitty @ launch --type=window $argv
        else
            echo "Error: 'spwin' detected Kitty but neither spawn-window.sh nor the kitty binary is available." >&2
            return 1
        end
    else if test "$TERM_PROGRAM" = WezTerm
        if not type -q wezterm
            echo "Error: 'spwin' detected WezTerm but the wezterm binary is not installed." >&2
            return 1
        end
        wezterm cli spawn $argv
    else
        echo "Error: The 'spwin' command requires Kitty or WezTerm." >&2
        return 1
    end
end
