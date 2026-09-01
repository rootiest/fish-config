# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   logging/multiplexer-capture
#
# SYNOPSIS
#   _zellij_dump_log
#
# DESCRIPTION
#   Captures the current Zellij pane's scrollback to a timestamped log in
#   SCROLLBACK_HISTORY_DIR (default ~/.terminal_history). Zellij has no live
#   output-streaming facility like tmux's pipe-pane, so this performs a one-shot
#   zellij action dump-screen --full — intended to run on shell exit. Old
#   zellij_*.log files are pruned via _prune_terminal_logs to stay within
#   SCROLLBACK_HISTORY_MAX_FILES.
#
#   The C5 logging guard (__fish_config_op_logging) is evaluated here, at call
#   time, so toggling logging takes effect on the next exit without a restart.
#   No-op when logging is disabled, not inside Zellij ($ZELLIJ unset), or the
#   zellij binary is missing.
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   _zellij_dump_log
function _zellij_dump_log --description 'Dump the current Zellij pane scrollback to a log file, with pruning'
    __fish_config_op_enabled (status current-function); or return 0
    set -q ZELLIJ; or return 0
    type -q zellij; or return 0

    set -l log_dir (set -q SCROLLBACK_HISTORY_DIR; and echo $SCROLLBACK_HISTORY_DIR; or echo "$HOME/.terminal_history")
    set -l session (set -q ZELLIJ_SESSION_NAME; and echo $ZELLIJ_SESSION_NAME; or echo unknown)
    set -l pane_id (set -q ZELLIJ_PANE_ID; and echo $ZELLIJ_PANE_ID; or echo unknown)
    set -l timestamp (date "+%Y-%m-%d_%H-%M-%S")
    set -l log_file "$log_dir/zellij_"$session"-p"$pane_id"_"$timestamp".log"

    mkdir -p $log_dir
    # Dump to STDOUT and let this fish process write the file. `--path` makes the
    # zellij *server* write the file (its CWD/permissions, historically flaky);
    # capturing STDOUT keeps the write client-side and reliable. Drop the empty
    # file if the dump produced nothing (e.g. pane already torn down on exit).
    zellij action dump-screen --full --ansi >"$log_file" 2>/dev/null
    test -s "$log_file"; or command rm -f "$log_file"

    _prune_terminal_logs zellij
end
