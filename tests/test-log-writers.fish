#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for the C5 log writers' input handling: file-name sanitization of
# multiplexer session names (_terminal_log_safe_name), shell-escaping of the
# path handed to tmux pipe-pane, and _prune_terminal_logs tolerating an
# invalid SCROLLBACK_HISTORY_MAX_FILES.
#
# Runs isolated (no `# MODE:` marker). Neither tmux nor zellij is required:
# the testable logic is factored into helpers, and the pipe-pane check uses a
# fake `tmux` function that records its argument.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

section "log writers: _terminal_log_safe_name"

check "plain name unchanged" my-work_1.2 (_terminal_log_safe_name my-work_1.2)
check "space replaced" my_work (_terminal_log_safe_name 'my work')
check "metacharacters replaced" my_work___x_ (_terminal_log_safe_name 'my work;$(x)')
check "slashes and globs replaced" a_b__c_ (_terminal_log_safe_name 'a/b*?c[')
check "empty becomes unknown" unknown (_terminal_log_safe_name '')
check "no args becomes unknown" unknown (_terminal_log_safe_name)
check "result is a single line" 1 (_terminal_log_safe_name "a b	c" | count)

section "log writers: _tmux_pipe_log escapes the pipe-pane command"

set -l base (mktemp -d)
set -g __pipe_cmd
function tmux
    switch "$argv[1]"
        case display-message
            if test "$argv[3]" = '#{session_name}'
                echo 'my work;$(x)'
            else
                echo w0-p0
            end
        case pipe-pane
            set -g __pipe_cmd "$argv[2]"
    end
end
set -gx TMUX fake
set -gx SCROLLBACK_HISTORY_DIR "$base/dir with space"
_tmux_pipe_log
check "pipe-pane command issued" 1 (string match -q 'cat >> *' -- $__pipe_cmd; and echo 1; or echo 0)
# Run the recorded command through sh exactly as tmux would. The file must
# land at the sanitized name and nothing else may be created or executed.
echo hi | sh -c "$__pipe_cmd"
set -l made (command ls -1 $SCROLLBACK_HISTORY_DIR)
check "exactly one log created" 1 (count $made)
check "log name is sanitized" 1 (string match -qr '^tmux_my_work___x_-w0-p0_[0-9_-]+\.log$' -- $made[1]; and echo 1; or echo 0)
check "log received output" hi (cat $SCROLLBACK_HISTORY_DIR/$made[1])
functions -e tmux
set -e TMUX
set -e SCROLLBACK_HISTORY_DIR
command rm -rf $base

section "log writers: _prune_terminal_logs with invalid MAX_FILES"

for bad in abc '' -5 1.5 3x
    set -l d (mktemp -d)
    for i in (seq 1 5)
        touch $d/tmux_$i.log
    end
    set -lx SCROLLBACK_HISTORY_DIR $d
    set -lx SCROLLBACK_HISTORY_MAX_FILES $bad
    set -l err (_prune_terminal_logs tmux 2>&1 >/dev/null)
    set -l rc $status
    check "invalid '$bad': no error output" "" "$err"
    check "invalid '$bad': exit 0" 0 $rc
    check "invalid '$bad': falls back to 100 (nothing pruned)" 5 (count $d/tmux_*.log)
    command rm -rf $d
end

set -l d (mktemp -d)
for i in (seq 1 5)
    touch -d "2026-01-0$i" $d/tmux_$i.log
end
set -lx SCROLLBACK_HISTORY_DIR $d
set -lx SCROLLBACK_HISTORY_MAX_FILES 2
_prune_terminal_logs tmux
check "valid numeric limit still prunes" 2 (count $d/tmux_*.log)
check "newest files kept" "tmux_4.log tmux_5.log" (string join ' ' (command ls -1 $d))
set -lx SCROLLBACK_HISTORY_MAX_FILES 0
_prune_terminal_logs tmux
check "zero is a valid limit" 0 (count $d/tmux_*.log 2>/dev/null)
command rm -rf $d

report
