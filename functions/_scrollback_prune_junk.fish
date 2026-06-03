# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function _scrollback_prune_junk --description 'Remove empty, trivial, and Kitty UI noise logs'
    set -l dir (set -q SCROLLBACK_HISTORY_DIR; and echo $SCROLLBACK_HISTORY_DIR; or echo "$HOME/.terminal_history")
    if set -q argv[1]
        set dir $argv[1]
    end

    test -d $dir || return 0

    # Remove any completely empty log file regardless of source
    for f in $dir/*.log $dir/*.txt
        test -f $f || continue
        not test -s $f; and rm $f
    end

    # Remove any log with only a single meaningful line (e.g. [exited], a lone prompt, or a trivial error)
    for f in $dir/*.log $dir/*.txt
        test -f $f || continue
        set -l line_count (command cat $f | sed 's/\x1b\[[0-9;:]*[a-zA-Z]//g' | grep -cv '^\s*$')
        if test $line_count -le 1
            rm $f
        end
    end

    # Remove scrollback logs that are Kitty tab-rename prompts (UI noise, not real sessions)
    for f in $dir/scrollback_*.log $dir/scrollback_*.txt
        test -f $f || continue
        if command cat $f | sed 's/\x1b\[[0-9;:]*[a-zA-Z]//g' | grep -q 'Enter the new title for this tab below'
            rm $f
        end
    end
end
