# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# C5 — Logging & Capture: registers a fish_exit handler that dumps the current
# Zellij pane's scrollback to a log file when the shell exits. Unlike tmux
# (streamed live via pipe-pane), Zellij has no continuous-capture facility, so
# we snapshot once on exit via `zellij action dump-screen --full`.
#
# The handler is registered whenever fish runs inside Zellij; the C5 logging
# guard is evaluated inside _zellij_dump_log at exit time, so toggling
# __fish_config_op_logging takes effect on the next exit without a restart
# (no sync_logging coordination needed, since there is no live stream to stop).
#
# Event-handler functions must be defined at startup (conf.d) so the --on-event
# binding is registered; autoloaded functions in functions/ never register.

status is-interactive; or exit
type -q zellij; or exit
set -q ZELLIJ; or exit

function __zellij_dump_on_exit --on-event fish_exit \
    --description 'C5 event handler: dump Zellij pane scrollback on shell exit'
    _zellij_dump_log
end
