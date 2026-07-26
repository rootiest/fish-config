# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
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
# RETURNS
#   0  Tab opened successfully
#   1  No supported terminal found
#
# EXAMPLE
#   tab
function tab --description 'Spawn a new tab in the current terminal'
    # Opinionated guard (C4): integrations disabled
    if not __fish_config_op_enabled __fish_config_op_integrations
        set -l c_err (set_color red)
        set -l c_reset (set_color normal)
        echo "$c_err"'tab: disabled by __fish_config_op_integrations'"$c_reset" >&2
        return 1
    end

    set -l dir "$cdto"
    if test -z "$dir"
        set dir "$PWD"
    end

    if test "$TERM" = xterm-kitty
        kitty @ launch --type=tab --cwd="$dir" $argv
    else if test "$TERM_PROGRAM" = WezTerm
        wezterm cli spawn --cwd "$dir" $argv
    else if set -q KONSOLE_VERSION
        konsole --new-tab --workdir "$dir" $argv
    else
        echo "Error: No supported terminal found. Try Kitty, WezTerm, or Konsole." >&2
        return 1
    end
end
