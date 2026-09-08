# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#    __fish_help_header <name> [args...]
#
# DESCRIPTION
#    Prints <name>'s man-page comment header as a help menu on stdout.
#    Intended as the first statement of a user-facing function's body:
#
#        __fish_help_header (status current-function) $argv; and return 0
#
#    Returns 1 -- printing nothing -- ONLY when args[1] is not a help flag.
#    Every other outcome, including an unreadable or headerless source
#    file, prints something and returns 0. That asymmetry is load-bearing:
#    a return of 1 means "run the real body", and the real body of upgrade
#    is `paru -Syu --noconfirm`. A parse failure must never return 1.
#
#    Only args[1] is inspected, never the whole list. wake-lock, bkg,
#    split and spwin take a command to run as their arguments, so
#    scanning all of $argv would make `wake-lock rsync --help` print
#    wake-lock's own help instead of running rsync.
#
#    The header is read from the caller's source at call time rather than
#    from the generated manual, so it cannot go stale between a header
#    edit and a docs rebuild.
#
# ARGUMENTS
#    name      The calling function's name, from (status current-function)
#    args...   The caller's $argv, forwarded verbatim
#
# EXIT STATUS
#    0  Help was printed, including the degraded fallback
#    1  args[1] is not -h/--help; the caller should carry on
#
# EXAMPLE
#    __fish_help_header (status current-function) $argv; and return 0
#
# NOTES
#    Section labels are those of the manual SSOT parser in
#    docs/manualtools.py. CATEGORY, COMPONENT and DEPENDENCIES are build
#    metadata and are suppressed; SYNOPSIS renders as USAGE and EXAMPLE as
#    EXAMPLES.
function __fish_help_header --argument-names name
    # First argument only -- see DESCRIPTION.
    contains -- "$argv[2]" -h --help; or return 1

    set -l c_ttl (set_color --bold)
    set -l c_sec (set_color --bold brblue)
    set -l c_rst (set_color normal)
    set -l miss "  No documentation header found. Try: help config $name"

    set -l file (functions -D -- $name 2>/dev/null)
    if not test -f "$file"
        # Quoted: set_color yields an EMPTY LIST under TERM=dumb, and an
        # unquoted empty list in a concatenation annihilates the whole
        # word -- the title line would silently vanish wherever colour is
        # off, which is exactly where a test would be reading it.
        echo "$c_ttl$name$c_rst"
        echo $miss
        return 0
    end

    # Collect the contiguous comment run directly above `function <name>`,
    # walking backwards. This resolves multi-header files (fish-deps, gi,
    # y) without reimplementing manualtools._block_identity, and is more
    # accurate at runtime: in dops.fish it finds the header above
    # `function docker` rather than attributing it to the file stem.
    # One blank separator line is tolerated -- sponge_filter_secrets.fish
    # is the only file that has one. Do not remove this tolerance as dead
    # code.
    set -l lines (string split \n -- (command cat $file))
    set -l pat '^\s*function\s+'(string escape --style=regex -- $name)'(\s|$)'
    set -l start 0
    for i in (seq (count $lines))
        if string match -qr -- $pat $lines[$i]
            set start $i
            break
        end
    end

    set -l header
    if test $start -gt 1
        set -l j (math $start - 1)
        if test -z (string trim -- "$lines[$j]")
            set j (math $j - 1)
        end
        while test $j -ge 1; and string match -q '#*' -- $lines[$j]
            set -p header $lines[$j]
            set j (math $j - 1)
        end
    end

    # Render. Comment lines before the first `# LABEL` -- the copyright
    # preamble -- carry no label and are dropped, matching
    # manualtools._header_blocks.
    set -l skip CATEGORY COMPONENT DEPENDENCIES
    set -l label ""
    set -l out
    for line in $header
        set -l m (string match -r -- '^#\s+([A-Z][A-Z ]*[A-Z])\s*$' $line)
        if set -q m[2]
            set label $m[2]
            contains -- $label $skip; and continue
            set -l shown (string replace SYNOPSIS USAGE -- $label)
            set shown (string replace EXAMPLE EXAMPLES -- $shown)
            # One blank line before a heading, never two: the header's own
            # `#` separator has usually already emitted one.
            if set -q out[1]; and test -n (string trim -- "$out[-1]")
                set -a out ""
            end
            set -a out "$c_sec$shown$c_rst"
            continue
        end
        test -n "$label"; or continue
        contains -- $label $skip; and continue
        set -l body (string sub -s 2 -- $line)
        if string match -q '   *' -- $body
            set -a out "  "(string sub -s 4 -- $body)
        else
            set -a out (string trim -- $body)
        end
    end

    # Trim the trailing blank separator, mirroring
    # manualtools._trailing_blanks.
    while set -q out[-1]; and test -z (string trim -- "$out[-1]")
        set -e out[-1]
    end

    echo "$c_ttl$name$c_rst"
    if test (count $out) -eq 0
        echo $miss
    else
        # out[1] is always a heading -- a body line cannot precede the
        # first label -- so this blank is never doubled.
        echo ""
        printf '%s\n' $out
    end
    return 0
end
