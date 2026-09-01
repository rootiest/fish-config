# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _prune_terminal_logs <prefix>
#
# DESCRIPTION
#   Removes the oldest "<prefix>_*.log" files in SCROLLBACK_HISTORY_DIR
#   (default ~/.terminal_history) so the total count for that prefix stays
#   within SCROLLBACK_HISTORY_MAX_FILES (default 100). Files are sorted by
#   modification time, so the most recently written logs are kept — actively
#   appended logs (e.g. a tmux pipe-pane stream) survive.
#
#   Uses command ls/command rm to bypass the C1 shadows: the bare ls is
#   the eza wrapper, which injects OSC-8 hyperlink escapes into paths, and the
#   bare rm is the trash wrapper. The glob is expanded via set first so a
#   no-match (empty dir / first run) yields an empty list instead of a hard
#   "No matches for wildcard" error.
#
# ARGUMENTS
#   prefix  Log-name prefix to prune (e.g. tmux, zellij)
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   _prune_terminal_logs tmux
function _prune_terminal_logs --argument-names prefix --description 'Prune oldest <prefix>_*.log files beyond the configured max'
    set -q prefix[1]; or return 0
    set -l log_dir (set -q SCROLLBACK_HISTORY_DIR; and echo $SCROLLBACK_HISTORY_DIR; or echo "$HOME/.terminal_history")
    set -l max_files (set -q SCROLLBACK_HISTORY_MAX_FILES; and echo $SCROLLBACK_HISTORY_MAX_FILES; or echo 100)
    test -d $log_dir; or return 0

    # Glob via `set` so a no-match yields an empty list rather than an error.
    set -l logs $log_dir/$prefix"_"*.log
    set -q logs[1]; or return 0

    # Re-sort by mtime, oldest first. Pass explicit files (no glob) so ls can
    # never fail on no-match; `command ls` avoids the eza OSC-8 corruption.
    set logs (command ls -1tr $logs 2>/dev/null)
    if test (count $logs) -gt $max_files
        set -l excess (math (count $logs) - $max_files)
        command rm -f $logs[1..$excess]
    end
end
