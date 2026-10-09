# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   tmux, _private_dir, _prune_terminal_logs, _terminal_log_safe_name
#
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
#   The session name is sanitized (_terminal_log_safe_name) before it becomes
#   part of the file name, and the final path is shell-escaped before being
#   handed to tmux, which runs the pipe-pane command through sh -c.
#
#   Logs are private: the directory is created 700 (an existing laxer one is
#   tightened silently, see _private_dir) and the pipe-pane command runs
#   under umask 077 so the log file is created 600 whatever the umask.
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   _tmux_pipe_log
function _tmux_pipe_log --description 'Start tmux pipe-pane capture for the current pane, with pruning'
    set -q TMUX; or return 0
    type -q tmux; or return 0

    set -l log_dir (set -q SCROLLBACK_HISTORY_DIR; and echo $SCROLLBACK_HISTORY_DIR; or echo "$HOME/.terminal_history")
    set -l session (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l win_pane (tmux display-message -p 'w#{window_index}-p#{pane_index}' 2>/dev/null)
    set -l pane_id (_terminal_log_safe_name "$session")-$win_pane
    set -l timestamp (date "+%Y-%m-%d_%H-%M-%S")
    set -l log_file "$log_dir/tmux_"$pane_id"_"$timestamp".log"

    _private_dir $log_dir files
    _prune_terminal_logs tmux

    # tmux hands this string to sh -c, so the path must be shell-escaped. The
    # umask makes sh create the log file 600.
    tmux pipe-pane "umask 077; cat >> "(string escape --style=script -- $log_file) 2>/dev/null
end
