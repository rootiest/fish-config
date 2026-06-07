# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   config-help [section]
#   config-help --help
#
# DESCRIPTION
#   Opens the offline fish shell configuration manual in the best available
#   pager. Falls back through ov -> bat -> man -> less -> cat.
#   If a section keyword is provided, the pager opens at the first heading
#   that matches the keyword. Lookup order: docs/fish-config.index (exact
#   keyword aliases), then a normalized heading scan as fallback.
#   When opened with ov a sticky navigation hint is shown at the top of the
#   screen. Pass --help or -h to print usage and navigation key reference.
#
# ARGUMENTS
#   section   Optional keyword to jump to a matching section heading
#   --help    Print usage and navigation reference, then exit
#   -h        Alias for --help
#
# RETURNS
#   0  Manual displayed (or --help printed)
#   1  Documentation file not found
#
# EXAMPLE
#   config-help
#   config-help keybindings
#   config-help pkg
#   config-help fish-deps
#   config-help --help
function config-help --description 'Open the offline fish shell configuration manual'
    # ── --help / -h ──────────────────────────────────────────────
    if contains -- --help $argv; or contains -- -h $argv
        set_color --bold
        echo config-help
        set_color normal
        echo " — view the offline fish shell configuration manual"
        echo ""
        set_color --bold brblue
        echo USAGE
        set_color normal
        echo "  config-help "(set_color yellow)"[section]"(set_color normal)
        echo "  config-help "(set_color yellow)"--help"(set_color normal)
        echo ""
        set_color --bold brblue
        echo ARGUMENTS
        set_color normal
        echo "  "(set_color yellow)"section"(set_color normal)"   Optional keyword to jump to a matching section heading."
        echo "            Searches docs/fish-config.index for aliases first, then"
        echo "            falls back to a normalized (case- and punctuation-insensitive)"
        echo "            scan of heading lines."
        echo ""
        set_color --bold brblue
        echo EXAMPLES
        set_color normal
        echo "  "(set_color green)"config-help"(set_color normal)"                  open at top"
        echo "  "(set_color green)"config-help keybindings"(set_color normal)"      jump to Key Bindings section"
        echo "  "(set_color green)"config-help pkg"(set_color normal)"              jump to the pkg function entry"
        echo "  "(set_color green)"config-help fish-deps"(set_color normal)"        jump to fish-deps"
        echo "  "(set_color green)"config-help abbreviations"(set_color normal)"    jump to Abbreviations section"
        echo ""
        set_color --bold brblue
        echo "NAVIGATION (ov pager)"
        set_color normal
        echo "  "(set_color cyan)"Space"(set_color normal)"       next section"
        echo "  "(set_color cyan)"^"(set_color normal)"           previous section"
        echo "  "(set_color cyan)"Alt+u"(set_color normal)"       toggle section list sidebar"
        echo "  "(set_color cyan)"/"(set_color normal)"           search forward"
        echo "  "(set_color cyan)"n"(set_color normal)" / "(set_color cyan)"N"(set_color normal)"       next / previous search match"
        echo "  "(set_color cyan)"g"(set_color normal)"           go to line number"
        echo "  "(set_color cyan)"q"(set_color normal)"           quit"
        echo ""
        set_color --bold brblue
        echo "PAGER FALLBACK CHAIN"
        set_color normal
        echo "  "(set_color brblack)"1."(set_color normal)" ov + bat   section nav + syntax highlighting  "(set_color brblack)"(best)"(set_color normal)
        echo "  "(set_color brblack)"2."(set_color normal)" ov alone   section nav, raw Markdown"
        echo "  "(set_color brblack)"3."(set_color normal)" bat alone  syntax highlighting, use / to search"
        echo "  "(set_color brblack)"4."(set_color normal)" man -l     pre-compiled man page (if available)"
        echo "  "(set_color brblack)"5."(set_color normal)" less       plain text with line-jump"
        echo "  "(set_color brblack)"6."(set_color normal)" cat        plain output"
        return 0
    end

    set -l doc_file "$__fish_config_dir/docs/fish-config.md"
    set -l idx_file "$__fish_config_dir/docs/fish-config.index"
    set -l man_file "$__fish_config_dir/docs/fish-config.1"

    if not test -f "$doc_file"
        set_color red
        echo "error: documentation not found at $doc_file" >&2
        set_color normal
        return 1
    end

    # ── Resolve section start line ───────────────────────────────
    # 1. Look up keyword in fish-config.index (keyword → exact heading text).
    # 2. Fall back to normalized scan of heading lines if not in index.
    # 3. Resolve start_line via grep -F on the heading text (immune to line
    #    number drift — only breaks if the heading itself is renamed).
    set -l start_line 1
    if test -n "$argv[1]"
        set -l norm_kw (string lower -- $argv[1] | string replace -ra '[^a-z0-9]' '')
        set -l found_text ""

        # ── Index lookup ─────────────────────────────────────────
        if test -f "$idx_file"
            while read -l idxline
                string match -qr '^[[:space:]]*(#|$)' -- $idxline; and continue
                set -l kv (string split -m 1 '=' -- $idxline)
                test (count $kv) -lt 2; and continue
                set -l k (string lower -- $kv[1] | string replace -ra '[^a-z0-9]' '')
                if test "$k" = "$norm_kw"
                    set found_text $kv[2]
                    break
                end
            end <"$idx_file"
        end

        # ── Normalized scan fallback ─────────────────────────────
        if test -z "$found_text"
            for entry in (grep -n "^#" "$doc_file")
                set -l parts (string split -m 1 ':' -- $entry)
                set -l text $parts[2]
                set -l norm_text (string lower -- $text | string replace -ra '[^a-z0-9]' '')
                if string match -q "*$norm_kw*" $norm_text
                    set found_text $text
                    break
                end
            end
        end

        if test -n "$found_text"
            set -l lnum (grep -Fn "$found_text" "$doc_file" | cut -d: -f1 | head -1)
            if test -n "$lnum"
                set start_line $lnum
            end
        else
            set_color yellow
            echo "note: no section matching '$argv[1]' — opening at top" >&2
            set_color normal
        end
    end

    # ── Navigation hint line ─────────────────────────────────────
    # Prepended to the ov input stream and pinned via --header 1 so it
    # remains visible at the top of the screen at all times.
    set -l nav_hint \
        " \033[2mNAVIGATION: [ Space=next section  ^=prev  Alt+u=sections  /=search  q=quit ]\033[0m"

    # ── Viewer fallback chain ────────────────────────────────────
    # When jumping to a section, slice the file from start_line so ov
    # opens with that section at the top without needing --pattern.
    # (--section-header pins delimiter lines as sticky headers, removing
    # them from pattern-search scope — tail-slice sidesteps this entirely.)
    if type -q ov; and type -q bat
        set -l ov_args \
            --header 1 \
            --section-delimiter "^#" \
            --section-header
        if test $start_line -gt 1
            begin
                printf "$nav_hint\n"
                bat --color=always --style=plain --language=markdown "$doc_file" \
                    | tail -n +$start_line
            end | ov $ov_args
        else
            begin
                printf "$nav_hint\n"
                bat --color=always --style=plain --language=markdown "$doc_file"
            end | ov $ov_args
        end

        # ov alone: section navigation on raw Markdown; no code highlighting.
    else if type -q ov
        set -l ov_args \
            --header 1 \
            --section-delimiter "^#" \
            --section-header
        if test $start_line -gt 1
            begin
                printf "$nav_hint\n"
                tail -n +$start_line "$doc_file"
            end | ov $ov_args
        else
            begin
                printf "$nav_hint\n"
                cat "$doc_file"
            end | ov $ov_args
        end

        # bat alone: syntax highlighting with built-in paging; no line jump.
    else if type -q bat
        if test $start_line -gt 1
            set_color brblack
            echo "note: bat pager — use / to search for your section" >&2
            set_color normal
        end
        bat --language=markdown --paging=always "$doc_file"

        # Pre-compiled man page (generated by CI after merge).
    else if test -f "$man_file"
        man -l "$man_file"

    else if type -q less
        less +"$start_line" "$doc_file"

    else
        cat "$doc_file"
    end
end
