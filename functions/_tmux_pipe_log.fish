# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _tmux_pipe_log
#
# DESCRIPTION
#   Starts tmux pipe-pane capture for the current pane, streaming its output
#   to a timestamped log in SCROLLBACK_HISTORY_DIR (default ~/.terminal_history).
#   Old tmux_*.log files are pruned via _prune_terminal_logs to stay within
#   SCROLLBACK_HISTORY_MAX_FILES. No-op when not inside a tmux session ($TMUX
#   unset) or tmux is missing. Shared by conf.d/tmux-logging.fish (shell
#   startup) and __fish_config_sync_logging (C5 re-enable) so both stay in sync.
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   _tmux_pipe_log
function _tmux_pipe_log --description 'Start tmux pipe-pane capture for the current pane, with pruning'
    set -q TMUX; or return 0
    type -q tmux; or return 0

    set -l log_dir (set -q SCROLLBACK_HISTORY_DIR; and echo $SCROLLBACK_HISTORY_DIR; or echo "$HOME/.terminal_history")
    set -l pane_id (tmux display-message -p '#{session_name}-w#{window_index}-p#{pane_index}' 2>/dev/null)
    set -l timestamp (date "+%Y-%m-%d_%H-%M-%S")
    set -l log_file "$log_dir/tmux_"$pane_id"_"$timestamp".log"

    mkdir -p $log_dir
    _prune_terminal_logs tmux

    tmux pipe-pane "cat >> $log_file" 2>/dev/null
end
