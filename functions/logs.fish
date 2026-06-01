# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function logs --description 'Browse terminal log files interactively with fzf'
    set -l options h/help c/category=
    argparse $options -- $argv
    or return 1

    if set -q _flag_help
        set -l c_accent (set_color green)
        set -l c_primary (set_color cyan)
        set -l c_bold (set_color --bold)
        set -l c_reset (set_color normal)
        echo "Usage: "$c_accent"logs"$c_reset" ["$c_primary"OPTIONS"$c_reset"]"
        echo ""
        echo "Browse and open terminal log files interactively."
        echo "Logs sorted newest-first. Type to fuzzy-filter by date or category."
        echo ""
        echo "Options:"
        echo "  "$c_primary"-h, --help"$c_reset"       Show this help"
        echo "  "$c_primary"-c, --category"$c_reset"   Limit to one category: scrollback, paru"
        echo ""
        echo "Keys in fzf:"
        echo "  "$c_primary"Enter"$c_reset"     Open in \$PAGER"
        echo "  "$c_primary"Ctrl-E"$c_reset"    Open in \$EDITOR"
        echo "  "$c_primary"Ctrl-C"$c_reset"    Quit"
        return 0
    end

    set -l log_dir (set -q SCROLLBACK_HISTORY_DIR; and echo $SCROLLBACK_HISTORY_DIR; or echo "$HOME/.terminal_history")
    set -l editor (set -q EDITOR; and echo $EDITOR; or echo nvim)

    # Scan primary dir and the legacy kitty dir (deduped)
    set -l scan_dirs $log_dir
    set -l legacy_dir "$HOME/.terminal_history"
    if test -d $legacy_dir; and not contains $legacy_dir $scan_dirs
        set -a scan_dirs $legacy_dir
    end

    # Collect entries: "SORTKEY|FILEPATH|CATEGORY"
    set -l entries
    for dir in $scan_dirs
        test -d $dir || continue
        for f in $dir/*.log $dir/*.txt
            test -f $f || continue
            set -l base (string replace -r '\.(log|txt)$' '' (basename $f))
            set -l ts (string match -r '[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}' $base)
            test -n "$ts" || continue
            set -l cat (string replace "_$ts" '' $base)
            if set -q _flag_category; and test $cat != $_flag_category
                continue
            end
            set -a entries "$ts|$f|$cat"
        end
    end

    if test (count $entries) -eq 0
        echo "No log files found"
        return 1
    end

    # Sort newest-first (ISO timestamp prefix is lexicographically correct)
    set -l sorted (printf '%s\n' $entries | sort -r)

    # Build fzf input lines: "FILEPATH<TAB>DATETIME  [CATEGORY]"
    # Field 1 (hidden via --with-nth 2) = filepath for use in {1} placeholders
    set -l fzf_lines
    for entry in $sorted
        set -l parts (string split '|' $entry)
        set -l ts_parts (string split '_' $parts[1])
        set -l date $ts_parts[1]
        set -l time (string replace -ra '-' ':' $ts_parts[2])

        # Declare before switch so the variable survives past the block
        set -l label "[$parts[3]]"
        switch $parts[3]
            case scrollback
                set label (printf '\033[36m[scrollback]\033[0m')
            case paru
                set label (printf '\033[32m[paru      ]\033[0m')
        end

        set -a fzf_lines (printf '%s\t%s %s  %s' $parts[2] $date $time $label)
    end

    set -l selected (printf '%s\n' $fzf_lines | fzf \
        --ansi \
        --delimiter '\t' \
        --with-nth 2 \
        --preview 'command cat {1}' \
        --preview-window 'right:60%:wrap' \
        --prompt 'Terminal Logs -> ' \
        --header 'Enter: View  Ctrl-E: Edit  Ctrl-C: Quit  (type to filter by date or category)' \
        --bind "ctrl-e:execute($editor {1})")

    test -n "$selected" || return 0

    set -l file (echo $selected | cut -f1)
    test -f $file || return 1
    if command -q $PAGER
        command cat $file | command $PAGER
    else
        command cat $file
    end
end
