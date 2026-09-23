# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# COMPONENT
#   integrations/window-mgmt
#
# DEPENDENCIES
#   kitty, wezterm, konsole
#
# SYNOPSIS
#   tab [args...]
#
# DESCRIPTION
#   Opens a new tab in Kitty, WezTerm, or Konsole using the current
#   working directory (or $cdto if set). Arguments are forwarded to the
#   terminal's tab-open command.
#
# ARGUMENTS
#   args...  Arguments forwarded to the terminal's launch command
#
# EXIT STATUS
#   0  Tab opened successfully
#   1  No supported terminal found
#
# EXAMPLE
#   tab
function tab --description 'Spawn a new tab in the current terminal'
    __fish_help_header (status current-function) $argv; and return 0

    # Opinionated guard (C4): integrations disabled
    if not __fish_config_op_enabled (status current-function)
        __fish_palette
        echo "$c_err"'tab: disabled by __fish_config_op_integrations'"$c_reset" >&2
        return 1
    end

    set -l dir "$cdto"
    if test -z "$dir"
        set dir "$PWD"
    end

    # $TERM/$TERM_PROGRAM/$KONSOLE_VERSION only prove the terminal type,
    # not that its CLI binary is on $PATH -- e.g. sshing out from one of
    # these inherits the env var on the remote host without the binary.
    # Check explicitly.
    if test "$TERM" = xterm-kitty
        if not type -q kitty
            echo "Error: 'tab' detected Kitty but the kitty binary is not installed." >&2
            return 1
        end
        kitty @ launch --type=tab --cwd="$dir" $argv
    else if test "$TERM_PROGRAM" = WezTerm
        if not type -q wezterm
            echo "Error: 'tab' detected WezTerm but the wezterm binary is not installed." >&2
            return 1
        end
        wezterm cli spawn --cwd "$dir" $argv
    else if set -q KONSOLE_VERSION
        if not type -q konsole
            echo "Error: 'tab' detected Konsole but the konsole binary is not installed." >&2
            return 1
        end
        konsole --new-tab --workdir "$dir" $argv
    else
        echo "Error: No supported terminal found. Try Kitty, WezTerm, or Konsole." >&2
        return 1
    end
end
