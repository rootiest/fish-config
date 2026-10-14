# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   greeting/first-run

#
# C6 -- First-run UI: tells an interactive shell, once, that `session-env`
# can export fish-config variables to the whole login session (apps started
# from the desktop never see config.fish). It prints one hint and never asks
# a question, so it cannot block a shell (scripted terminals, multiplexers).
# The answer is taken by `session-env setup`, which asks on a terminal only;
# `session-env dismiss` records "no". Either, or this notice appearing once,
# sets the universal variable below, so the offer is never repeated. To see
# it again: set -Ue __fish_config_session_env_offered

status is-interactive; or exit
__fish_config_op_enabled (status basename); or exit
set -q __fish_config_session_env_offered; and exit
# environment.d is a systemd feature (a stat call, no fork).
__session_env_has_systemd; or exit
set -l _cfg $XDG_CONFIG_HOME
test -n "$_cfg"; or set _cfg $HOME/.config
test -e $_cfg/environment.d/fish-config.conf; and exit

set -U __fish_config_session_env_offered 1
echo "  Tip: apps launched from the desktop do not see variables set in config.fish."
echo "  Run 'session-env setup' to export the default group (XDG dirs) to your"
echo "  whole session, or 'session-env dismiss' to stop this hint."
