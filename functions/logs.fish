# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   11-pager-and-logging
#
# SYNOPSIS
#   logs [-h] [-c <category>]
#
# DESCRIPTION
#   Interactively browses terminal log files (scrollback, paru, yay) sorted
#   newest-first using fzf. Supports viewing in $PAGER, editing, and deletion.
#
# ARGUMENTS
#   -h, --help           Show help message
#   -c, --category cat   Filter to one category: scrollback, paru, or yay
#
# RETURNS
#   0  File viewed or no file selected
#   1  No log files found
#
# EXAMPLE
#   logs -c paru
function logs --description 'Browse terminal log files interactively with fzf'
    # Opinionated guard (C4): integrations disabled
    if not __fish_config_op_enabled __fish_config_op_integrations
        set -l c_err (set_color red)
        set -l c_reset (set_color normal)
        echo "$c_err"'logs: disabled by __fish_config_op_integrations'"$c_reset" >&2
        return 1
    end

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
        echo "  "$c_primary"-c, --category"$c_reset"   Limit to one category: scrollback, paru, yay"
        echo ""
        echo "Keys in fzf:"
        echo "  "$c_primary"Enter"$c_reset"     Open in \$PAGER"
        echo "  "$c_primary"Ctrl-E"$c_reset"    Open in \$EDITOR"
        echo "  "$c_primary"Ctrl-D"$c_reset"    Delete selected log"
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

    # Strip junk scrollback logs before building the file list
    for dir in $scan_dirs
        _scrollback_prune_junk $dir
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
            case yay
                set label (printf '\033[33m[yay       ]\033[0m')
        end

        set -a fzf_lines (printf '%s\t%s %s  %s' $parts[2] $date $time $label)
    end

    set -l tmpfile (mktemp)
    set -l helpfile (mktemp)
    set -l togglescript (mktemp)
    set -l deletescript (mktemp)
    set -l helpflag "$tmpfile.help"
    printf '%s\n' $fzf_lines > $tmpfile
    printf 'Terminal Logs — Key Bindings\n\n  Enter     View selected log in pager\n  Ctrl-E    Edit selected log in editor\n  Ctrl-D    Delete selected log\n  Ctrl-C    Quit\n  ?         Toggle this help\n\nFiltering:\n  Type to fuzzy-filter by date or category\n  Use -c flag to limit: scrollback, paru, yay' > $helpfile
    # Help toggle script — avoids nested parens inside transform()
    printf '#!/bin/sh\nif test -f %s; then\n  rm -f %s\n  printf "change-preview(command cat {1})"\nelse\n  touch %s\n  printf "change-preview(command cat %s)"\nfi\n' \
        $helpflag $helpflag $helpflag $helpfile > $togglescript
    chmod +x $togglescript
    # Delete confirmation script — avoids nested parens inside execute(), and ensures
    # tmpfile is updated before +reload fires (execute is synchronous, execute-silent is not)
    printf '%s\n' \
        '#!/bin/sh' \
        'FILE="$1"' \
        'printf "Delete %s? [Y/n] " "$(basename "$FILE")"' \
        'read confirm' \
        'case "$confirm" in [nN]) exit 0 ;; esac' \
        "fish -c \"rm \$FILE\"" \
        "grep -vF \"\$FILE\" $tmpfile > $tmpfile.new" \
        "mv $tmpfile.new $tmpfile" \
        > $deletescript
    chmod +x $deletescript

    set -l selected (command cat $tmpfile | fzf \
        --ansi \
        --delimiter '\t' \
        --with-nth 2 \
        --preview 'command cat {1}' \
        --preview-window 'right:60%:wrap' \
        --prompt 'Terminal Logs -> ' \
        --header '?: Help  Enter: View  Ctrl-E: Edit  Ctrl-D: Delete  Ctrl-C: Quit' \
        --bind "ctrl-e:execute($editor {1})" \
        --bind "ctrl-d:execute($deletescript {1})+reload(command cat $tmpfile)" \
        --bind "?:transform($togglescript)")

    rm -f $tmpfile $tmpfile.new $helpfile $helpflag $togglescript $deletescript

    test -n "$selected" || return 0

    set -l file (echo $selected | cut -f1)
    test -f $file || return 1

    set -l base (basename $file)

    # 1. Maintain base multi-color parsing highlights
    set -l paru_flags -M "^\s*:: .*,upgrading \S+,downloading\.\.\.,\(\s*\d+/\d+\),(Total.*Size:|Net Upgrade Size:|\s*Package \(\d+\))"

    set -l use_ov 0
    if command -q ov
        if not set -q PAGER; or test "$PAGER" = ov
            set use_ov 1
        end
    end

    if test $use_ov -eq 1
        if string match -qr '^(paru|yay)' $base
            set -l section_regex '^\s*Package \(\d+\)|^\s*:: (Proceed|Retrieving|Running pre-transaction|Processing package changes|Running post-transaction|Looking for .* upgrades\.\.\.)|^\s*==>'
            set paru_flags $paru_flags --section-delimiter $section_regex --section-header -c
            command ov $paru_flags $file
        else if string match -qr '^scrollback' $base
            # Write a minimal ov config to a temp file so the section header
            # is displayed without ov's default slateblue background, preserving
            # the original ANSI colors of the starship prompt.
            set -l ov_cfg (mktemp --suffix .yaml)
            printf 'Mode:\n  scrollback:\n    Style:\n      SectionLine:\n        Background: ""\n        Foreground: ""\n' > $ov_cfg
            command ov --config $ov_cfg --view-mode scrollback \
                --section-delimiter '\x1b\]133;A' --section-header --section-header-num 1 $file
            rm -f $ov_cfg
        else
            command ov $file
        end
    else if set -q PAGER; and command -q $PAGER
        command cat $file | command $PAGER
    else
        command cat $file
    end
end
