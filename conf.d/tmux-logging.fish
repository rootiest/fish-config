# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# C5 — Logging & Capture: starts a pipe-pane log for the current tmux pane
# when fish launches inside a tmux session. Each fish shell gets its own
# timestamped log file in SCROLLBACK_HISTORY_DIR (default: ~/.terminal_history).
# Naming: tmux_<session>-w<window>-p<pane>_YYYY-MM-DD_HH-MM-SS.log

__fish_config_op_enabled __fish_config_op_logging; or exit
status is-interactive; or exit
type -q tmux; or exit
set -q TMUX; or exit

_tmux_pipe_log
