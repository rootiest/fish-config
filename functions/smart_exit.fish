# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   smart_exit [-h] [-n]
#
# DESCRIPTION
#   Closes the shell session, capturing and archiving the terminal scrollback
#   log before exit (Kitty only). Automatically prunes junk and excess log
#   files according to $SCROLLBACK_HISTORY_MAX_FILES.
#
# ARGUMENTS
#   -h, --help    Show help message
#   -n, --no-log  Exit without saving a scrollback log
#
# RETURNS
#   0  Shell session exited
#   1  Argument parsing failed
#
# EXAMPLE
#   smart_exit --no-log
function smart_exit --description 'Capture colorized scrollback before exiting, with pruning and safe overrides'
    # Opinionated guard (C3): exit plainly when overrides are disabled.
    # This composes with Task #4's __fish_config_enable_logging, which will
    # gate only the scrollback capture while leaving the exit wrapper active.
    if not __fish_config_op_enabled __fish_config_op_overrides
        builtin exit $argv
    end

    set -l options h/help n/no-log
    argparse $options -- $argv
    or return 1

    set -l c_primary (set_color cyan)
    set -l c_accent (set_color green)
    set -l c_warn (set_color yellow)
    set -l c_bold (set_color --bold)
    set -l c_reset (set_color normal)

    if set -q _flag_help
        echo -e "Usage: $c_accent"exit"$c_reset [$c_primary""OPTIONS""$c_reset]"
        echo ""
        echo "Closes the current shell session, automatically archiving the window scrollback."
        echo ""
        echo "Options:"
        echo -e "  $c_primary""-h, --help""$c_reset    Show this help message"
        echo -e "  $c_primary""-n, --no-log""$c_reset  Exit immediately $c_bold""without""$c_reset saving a scrollback history log"
        return 0
    end

    # C5 — Logging & Capture: skip all capture when logging is disabled.
    # When disabled, tell Kitty the window is handled so its watcher doesn't
    # capture either — belt-and-suspenders alongside the sentinel file.
    if not __fish_config_op_enabled __fish_config_op_logging
        if test -n "$KITTY_WINDOW_ID"
            kitty @ set-user-vars "logged_by_shell=true" 2>/dev/null
        end
        builtin exit
    end

    set -l snapshot_dir (set -q SCROLLBACK_HISTORY_DIR; and echo $SCROLLBACK_HISTORY_DIR; or echo "$HOME/.terminal_history")
    set -l max_files (set -q SCROLLBACK_HISTORY_MAX_FILES; and echo $SCROLLBACK_HISTORY_MAX_FILES; or echo 100)

    # Handle Scrollback Capture (Skipped if -n/--no-log is used)
    if not set -q _flag_no_log
        mkdir -p $snapshot_dir
        set -l timestamp (date "+%Y-%m-%d_%H-%M-%S")
        set -l filename "$snapshot_dir/scrollback_$timestamp.log"

        # Safe child process detection
        set -l active_tui (ps -o comm= --ppid $fish_pid 2>/dev/null)

        if test -n "$KITTY_WINDOW_ID"
            # LIVE BUFFER CHECK: Check the active token variable $_
            # If the user typed exit, $_ will match "exit". If flags were passed,
            # we check if it contains the phrase "exit" to match 'exit -n' or 'exit --help'.
            if string match -qr exit "$_"
                if not string match -qr '^(nvim|vim|vi|nano|emacs|tmux)$' "$active_tui"
                    # Capture the log via the shell
                    kitty @ get-text --match id:$KITTY_WINDOW_ID --extent all --ansi | sed 's/^\[38;2;[0-9;]*m//g' >$filename 2>/dev/null
                    # Broadcast a window variable flag telling Kitty the log is handled
                    kitty @ set-user-vars "logged_by_shell=true" 2>/dev/null
                end
            end
        end

        # 4. Prune junk logs before counting toward the max
        _scrollback_prune_junk $snapshot_dir

        # 5. Automatic Pruning Logic
        set -l current_logs $snapshot_dir/scrollback_*.log
        if test -f "$current_logs[1]"
            set -l total_files (count $current_logs)
            if test $total_files -gt $max_files
                set -l num_to_delete (math $total_files - $max_files)
                for i in (seq 1 $num_to_delete)
                    rm -f $current_logs[$i]
                end
            end
        end
    else
        echo -e "$c_warn""➔""$c_reset Exiting discreetly; $c_bold""no history logs saved.""$c_reset"
        sleep 0.4
    end

    # Call the true system exit directly
    builtin exit
end
