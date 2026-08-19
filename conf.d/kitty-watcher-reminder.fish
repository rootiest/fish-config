# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   logging/terminal-capture

#
# C5 — Logging & Capture: a non-blocking, per-session reminder shown inside Kitty
# when the fish-config scrollback watcher is not yet set up. It never blocks the
# shell; it simply prints how to enable or silence it. The notice stops once the
# user runs `kitty-logging install` (a watcher line then exists in kitty.conf) or
# `kitty-logging dismiss` (sets the universal variable below).

status is-interactive; or exit
type -q kitty; or exit
set -q KITTY_WINDOW_ID; or exit
__fish_config_op_enabled (status basename); or exit
__fish_variable_check __fish_config_kitty_watcher_dismissed; and exit
__kitty_logging_has_watcher; and exit

set_color --bold yellow
echo "Kitty session logging is available but not set up."
set_color normal
echo "  Enable:  kitty-logging install"
echo "  Silence: kitty-logging dismiss"
