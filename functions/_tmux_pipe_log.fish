# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _tmux_pipe_log
#
# DESCRIPTION
#   Starts tmux pipe-pane capture for the current pane, streaming its output
#   to a timestamped log in SCROLLBACK_HISTORY_DIR (default ~/.terminal_history).
#   Before starting, prunes the oldest tmux_*.log files so that the total stays
#   within SCROLLBACK_HISTORY_MAX_FILES (default 100), leaving room for the new
#   log. No-op when not inside a tmux session ($TMUX unset) or tmux is missing.
#   Shared by conf.d/tmux-logging.fish (shell startup) and
#   __fish_config_sync_logging (C5 re-enable) so both stay in sync.
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
    set -l max_files (set -q SCROLLBACK_HISTORY_MAX_FILES; and echo $SCROLLBACK_HISTORY_MAX_FILES; or echo 100)
    set -l pane_id (tmux display-message -p '#{session_name}-w#{window_index}-p#{pane_index}' 2>/dev/null)
    set -l timestamp (date "+%Y-%m-%d_%H-%M-%S")
    set -l log_file "$log_dir/tmux_"$pane_id"_"$timestamp".log"

    mkdir -p $log_dir

    # Prune oldest logs, leaving room for the one we're about to create.
    # Names carry a per-pane prefix, so sort by mtime (command ls -tr = oldest
    # first). Use `command ls`: the bare `ls` is shadowed by the eza wrapper,
    # which injects OSC-8 escapes into paths and corrupts the filenames.
    set -l keep (math max 0, $max_files - 1)
    set -l logs (command ls -1tr $log_dir/tmux_*.log 2>/dev/null)
    if test (count $logs) -gt $keep
        set -l excess (math (count $logs) - $keep)
        command rm -f $logs[1..$excess]
    end

    tmux pipe-pane "cat >> $log_file" 2>/dev/null
end
