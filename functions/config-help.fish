# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# CLASSIFICATION
#   self-limiting(grep), bypasses-shadow(less)
#
# SYNOPSIS
#   config-help [section]
#   config-help --html
#   config-help [section] --man
#   config-help --help
#
# DESCRIPTION
#   Opens the offline fish shell configuration manual in the best available
#   pager. Falls back through ov -> bat -> man -> less -> cat.
#   If a section keyword is provided, the pager opens at the first heading
#   that matches the keyword. Lookup order: docs/fish-config.index (exact
#   keyword aliases), then a normalized heading scan as fallback.
#   When opened with ov a sticky navigation hint is shown at the top of the
#   screen. Section matching is case-insensitive. Pass --html / -w to open
#   the published documentation website (https://fish.rootiest.fyi/)
#   in the default browser via xdg-open — deep links to a section aren't
#   supported there, so if a keyword is given a note points you to the site's
#   search box instead. Pass --man / -m to open the compiled man page
#   (docs/fish-config.1) via man -l; if a section keyword is given, the
#   pager opens at the nearest match. Pass --help or -h for usage and the
#   navigation key reference.
#
# ARGUMENTS
#   section     Optional keyword to jump to a matching section heading
#   -w, --html  Open the published documentation website in the default browser
#   -m, --man   Open the compiled man page via man -l
#   -h, --help  Print usage and navigation reference, then exit
#
# EXIT STATUS
#   0  Manual displayed
#   1  Documentation file not found, or required tool not available
#
# RETURNS
#   With -h/--help, the usage and navigation reference, printed to stdout.
#   Otherwise, the manual is shown via the resolved pager (not captured stdout).
#
# EXAMPLE
#   config-help
#   config-help keybindings
#   config-help pkg
#   config-help fish-deps
#   config-help --html
#   config-help --man
#   config-help keys --man
#   config-help --help
#   config-help pkg --man
#
# NOTES
#   The preferred invocation is help config [...] — this function is
#   registered as a handler in the help wrapper so that syntax works
#   transparently. Direct config-help calls are also valid.
function config-help --description 'Open the offline fish shell configuration manual'
    set -l doc_file "$__fish_config_dir/docs/fish-config.md"
    set -l idx_file "$__fish_config_dir/docs/fish-config.index"
    set -l man_file "$__fish_config_dir/docs/fish-config.1"
    set -l site_url "https://fish.rootiest.fyi/"

    # ── Extract section keyword (first non-flag argument) ────────
    set -l section_kw ""
    for arg in $argv
        if not string match -q -- '-*' $arg
            set section_kw $arg
            break
        end
    end

    # ── Resolve section keyword → heading text ───────────────────
    # Used by --html (anchor lookup), --man (search pattern), and the
    # pager fallback chain (line number). Runs once, shared by all paths.
    set -l found_text ""
    if test -n "$section_kw"
        set -l norm_kw (string lower -- $section_kw | string replace -ra '[^a-z0-9]' '')

        # Singular/plural variants of the keyword. The heading scan below
        # matches a keyword that is *contained in* a heading, so a plural
        # never reaches a singular heading on its own: `customization`
        # finds "7. CUSTOMIZATION", `customizations` finds nothing. The
        # keyword as typed is always tried first and alone; these only run
        # when it matched nothing at all.
        set -l kw_variants $norm_kw
        if test -n "$norm_kw"
            if string match -qr 's$' -- $norm_kw
                if string match -qr 'ies$' -- $norm_kw
                    set -a kw_variants (string replace -r 'ies$' y -- $norm_kw)
                end
                if string match -qr 'es$' -- $norm_kw
                    set -a kw_variants (string replace -r 'es$' '' -- $norm_kw)
                end
                set -a kw_variants (string replace -r 's$' '' -- $norm_kw)
            else
                set -a kw_variants "$norm_kw"s "$norm_kw"es
            end
        end

        # 1. Index lookup (keyword aliases)
        if test -f "$idx_file"
            while read -l idxline
                string match -qr '^[[:space:]]*(#|$)' -- $idxline; and continue
                set -l kv (string split -m 1 '=' -- $idxline)
                test (count $kv) -lt 2; and continue
                set -l k (string lower -- $kv[1] | string replace -ra '[^a-z0-9]' '')
                if contains -- $k $kw_variants
                    set found_text $kv[2]
                    break
                end
            end <"$idx_file"
        end

        # 2. Normalized heading scan fallback
        # Each variant is tried against every heading before the next one
        # is considered, so a loose plural never beats an exact hit that
        # appears further down the document.
        if test -z "$found_text"; and test -f "$doc_file"
            set -l heading_lines (grep -n "^#" "$doc_file")
            for kw in $kw_variants
                for entry in $heading_lines
                    set -l parts (string split -m 1 ':' -- $entry)
                    set -l text $parts[2]
                    set -l norm_text (string lower -- $text | string replace -ra '[^a-z0-9]' '')
                    if string match -q "*$kw*" $norm_text
                        set found_text $text
                        break
                    end
                end
                if test -n "$found_text"
                    break
                end
            end
        end
    end

    # ── --html / -w ──────────────────────────────────────────────
    if contains -- --html $argv; or contains -- -w $argv
        if test -n "$section_kw"
            set_color yellow
            echo "note: deep links aren't available on the website — opening the site root; use its search box to find '$section_kw'" >&2
            set_color normal
        end

        if type -q xdg-open
            xdg-open "$site_url" &>/dev/null &
            disown
        else
            set_color red
            echo "error: no opener found — visit $site_url" >&2
            set_color normal
            return 1
        end
        return 0
    end

    # ── --man / -m ───────────────────────────────────────────────
    if contains -- --man $argv; or contains -- -m $argv
        if not test -f "$man_file"
            set_color red
            echo "error: man page not found at $man_file" >&2
            set_color normal
            return 1
        end
        if not type -q man
            set_color red
            echo "error: man not found — cannot open man page" >&2
            set_color normal
            return 1
        end
        if test -n "$found_text"
            # Strip Markdown heading markers to get the bare section name,
            # then pass it as a less search pattern. MANPAGER is overridden
            # here because the bat renderer does not support +/pattern jumps.
            set -l pattern (string replace -ra '^#+ *' '' -- $found_text | string trim)
            # Single-quote the +/pattern inside the MANPAGER string so the
            # shell doesn't word-split headings that contain spaces.
            env MANPAGER="less '+/$pattern'" man -l "$man_file"
        else if test -n "$section_kw"
            set_color yellow
            echo "note: no section matching '$section_kw' — opening at top" >&2
            set_color normal
            man -l "$man_file"
        else
            man -l "$man_file"
        end
        return 0
    end

    # ── --help / -h ──────────────────────────────────────────────
    if contains -- --help $argv; or contains -- -h $argv
        __fish_palette
        echo "$c_cmd""help config / config-help$c_reset"
        echo " — view the offline fish shell configuration manual"
        echo ""
        echo "$c_head""USAGE$c_reset"
        echo "  $c_cmd""help config$c_reset $c_arg""[section]$c_reset"
        echo "  $c_cmd""help config$c_reset $c_arg""[section]$c_reset $c_flag--html$c_reset"
        echo "  $c_cmd""help config$c_reset $c_arg""[section]$c_reset $c_flag--man$c_reset"
        echo "  $c_cmd""help config$c_reset $c_flag--help$c_reset"
        echo ""
        echo "$c_head""ARGUMENTS$c_reset"
        echo "  $c_arg""section$c_reset      Optional keyword to jump to a matching section heading."
        echo "               Searches docs/fish-config.index for aliases first, then"
        echo "               falls back to a normalized (case- and punctuation-insensitive)"
        echo "               scan of heading lines."
        echo "  $c_flag-w, --html$c_reset   Open the published documentation website in the default browser."
        echo "               Deep links aren't supported — use the site's search box."
        echo "  $c_flag-m, --man$c_reset    Open the compiled man page via man -l."
        echo "               If a section keyword is given, jumps to the nearest match."
        echo ""
        echo "$c_head""EXAMPLES$c_reset"
        echo "  $c_cmd""help config$c_reset                       open at top"
        echo "  $c_cmd""help config$c_reset $c_arg""keybindings$c_reset           jump to Key Bindings section"
        echo "  $c_cmd""help config$c_reset $c_arg""pkg$c_reset                   jump to the pkg function entry"
        echo "  $c_cmd""help config$c_reset $c_arg""fish-deps$c_reset             jump to fish-deps"
        echo "  $c_cmd""help config$c_reset $c_arg""abbreviations$c_reset         jump to Abbreviations section"
        echo "  $c_cmd""help config$c_reset $c_flag--html$c_reset                open the documentation website"
        echo "  $c_cmd""help config$c_reset $c_flag--man$c_reset                 open compiled man page"
        echo "  $c_cmd""help config$c_reset $c_arg""pkg$c_reset $c_flag--man$c_reset             open man page at pkg section"
        echo ""
        echo "$c_head""NAVIGATION (ov pager)$c_reset"
        echo "  $c_arg""Space$c_reset       next section"
        echo "  $c_arg""^$c_reset           previous section"
        echo "  $c_arg""Alt+u$c_reset       toggle section list sidebar"
        echo "  $c_arg""/$c_reset           search forward"
        echo "  $c_arg""n$c_reset / $c_arg""N$c_reset       next / previous search match"
        echo "  $c_arg""g$c_reset           go to line number"
        echo "  $c_arg""q$c_reset           quit"
        echo ""
        echo "$c_head""PAGER FALLBACK CHAIN$c_reset"
        echo "  $c_dim""1.$c_reset $c_cmd""ov$c_reset + $c_cmd""bat$c_reset   section nav + syntax highlighting  $c_dim""(best)$c_reset"
        echo "  $c_dim""2.$c_reset $c_cmd""ov$c_reset alone   section nav, raw Markdown"
        echo "  $c_dim""3.$c_reset $c_cmd""bat$c_reset alone  syntax highlighting, use / to search"
        echo "  $c_dim""4.$c_reset $c_cmd""man$c_reset $c_flag-l$c_reset     pre-compiled man page (if available)"
        echo "  $c_dim""5.$c_reset $c_cmd""less$c_reset       plain text with line-jump"
        echo "  $c_dim""6.$c_reset $c_cmd""cat$c_reset        plain output"
        return 0
    end

    if not test -f "$doc_file"
        set_color red
        echo "error: documentation not found at $doc_file" >&2
        set_color normal
        return 1
    end

    # ── Resolve section start line (for pager) ───────────────────
    # found_text is already resolved above; just need the line number.
    set -l start_line 1
    if test -n "$found_text"
        set -l lnum (grep -Fn "$found_text" "$doc_file" | cut -d: -f1 | head -1)
        if test -n "$lnum"
            set start_line $lnum
        end
    else if test -n "$section_kw"
        set_color yellow
        echo "note: no section matching '$section_kw' — opening at top" >&2
        set_color normal
    end

    # ── Navigation hint line ─────────────────────────────────────
    # Prepended to the ov input stream and pinned via --header 1 so it
    # remains visible at the top of the screen at all times.
    set -l nav_hint \
        " \033[2mNAVIGATION: [ Space=next section  ^=prev  Alt+u=sections  /=search  q=quit ]\033[0m"

    # ── Inline code spans ────────────────────────────────────────
    # The document carries backticks for pandoc and the docs site, but
    # nothing in this chain consumes them: bat dims the delimiters and
    # leaves the content the same colour as the surrounding prose, so
    # they arrive as literal punctuation. Render each span bold instead.
    #
    # Two forms are matched. After bat, every backtick carries its own
    # SGR sequence, and a fence survives because it puts three of them
    # inside one sequence. On raw Markdown a fence survives because it
    # offers no non-backtick content to capture. Both substitutions are
    # line-preserving, so the tail-slice below still lands on the
    # requested section.
    set -l span_ansi '\e\[[0-9;]*m`\e\[0m(.*?)\e\[[0-9;]*m`\e\[0m'
    set -l span_raw '`([^`]+)`'
    set -l span_bold (printf '\e[1m$1\e[0m')

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
                    | tail -n +$start_line \
                    | string replace -ra $span_ansi $span_bold
            end | ov $ov_args
        else
            begin
                printf "$nav_hint\n"
                bat --color=always --style=plain --language=markdown "$doc_file" \
                    | string replace -ra $span_ansi $span_bold
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
                tail -n +$start_line "$doc_file" \
                    | string replace -ra $span_raw $span_bold
            end | ov $ov_args
        else
            begin
                printf "$nav_hint\n"
                string replace -ra $span_raw $span_bold <"$doc_file"
            end | ov $ov_args
        end

        # bat alone: syntax highlighting with built-in paging; no line jump.
    else if type -q bat
        if test $start_line -gt 1
            set_color brblack
            echo "note: bat pager — use / to search for your section" >&2
            set_color normal
        end
        # bat owns the pager here, so the spans are flattened on the way
        # in rather than styled on the way out — bat would escape any
        # SGR sequence handed to it as input.
        string replace -ra $span_raw '$1' <"$doc_file" \
            | bat --language=markdown --paging=always

        # Pre-compiled man page (generated by CI after merge).
        # pandoc consumed the backticks when it built this, so there is
        # nothing to strip.
    else if test -f "$man_file"
        man -l "$man_file"

    else if type -q less
        string replace -ra $span_raw $span_bold <"$doc_file" \
            | command less -R +"$start_line"

    else
        string replace -ra $span_raw $span_bold <"$doc_file"
    end
end
