# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   config_help [section]
#
# DESCRIPTION
#   Opens the offline fish shell configuration manual in the best available
#   pager. Falls back through ov -> bat -> man -> less -> cat.
#   If a section keyword is provided, the pager opens at the first heading
#   that matches the keyword (case-insensitive).
#
# ARGUMENTS
#   section  Optional keyword to jump to a matching section heading
#
# RETURNS
#   0  Manual displayed
#   1  Documentation file not found
#
# EXAMPLE
#   config_help
#   config_help keybindings
#   config_help pkg
#   config_help fish-deps
function config_help --description 'Open the offline fish shell configuration manual'
    set -l doc_file "$__fish_config_dir/docs/fish-config.md"
    set -l man_file "$__fish_config_dir/docs/fish-config.1"

    if not test -f "$doc_file"
        set_color red
        echo "error: documentation not found at $doc_file" >&2
        set_color normal
        return 1
    end

    # ── Resolve section start line ───────────────────────────────
    set -l start_line 1
    if test -n "$argv[1]"
        set -l found (grep -n -im 1 "^#\+.*$argv[1]" "$doc_file" | cut -d: -f1)
        if test -n "$found"
            set start_line $found
        else
            set_color yellow
            echo "note: no section matching '$argv[1]' — opening at top" >&2
            set_color normal
        end
    end

    # ── Viewer fallback chain ────────────────────────────────────
    if type -q ov
        ov --syntax --syntax-name markdown \
           --section-delimiter "^#" \
           --section-header \
           +"$start_line" "$doc_file"

    else if type -q bat
        if test $start_line -gt 1
            # bat can't jump to a line in paging mode; show a hint instead
            set_color brblack
            echo "note: bat pager active — use / to search for your section" >&2
            set_color normal
        end
        bat --language=markdown --paging=always "$doc_file"

    else if test -f "$man_file"
        # Pre-compiled man page as a pager-independent fallback
        man -l "$man_file"

    else if type -q less
        less +"$start_line" "$doc_file"

    else
        cat "$doc_file"
    end
end
