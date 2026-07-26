# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __kitty_logging_dir
#
# DESCRIPTION
#   Echoes the Kitty configuration directory, mirroring Kitty's own resolution
#   order: $KITTY_CONFIG_DIRECTORY, else $XDG_CONFIG_HOME/kitty, else
#   ~/.config/kitty.
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The Kitty configuration directory path, printed to stdout
#
# EXAMPLE
#   set -l dir (__kitty_logging_dir)
function __kitty_logging_dir --description 'Resolve the Kitty config directory'
    if set -q KITTY_CONFIG_DIRECTORY; and test -n "$KITTY_CONFIG_DIRECTORY"
        echo $KITTY_CONFIG_DIRECTORY
    else if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        echo $XDG_CONFIG_HOME/kitty
    else
        echo $HOME/.config/kitty
    end
end
