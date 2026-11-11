# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   git
#
# SYNOPSIS
#   __empty_enter_list
#
# DESCRIPTION
#   Bound to Enter, ahead of __bashrun_execute. On an empty command line it
#   writes a listing command into the line, which the next binding then
#   executes, so the listing shows on screen and lands in history. Inside a
#   git work tree the line runs ls and then git status -sb. Everywhere else,
#   or when git is not installed, it runs ls alone. Any other line is left
#   alone, as is Enter in the completion pager or history search.
#
#   A line holding only a space is not empty: Space then Enter still gives
#   a fresh prompt without a listing, and fish keeps it out of history.
#
#   Set __fish_empty_enter_git to a falsy value (0, false, no, off, n) to
#   drop the git status part and run plain ls everywhere.
#
# EXAMPLE
#   bind enter __empty_enter_list __bashrun_execute
#   set -U __fish_empty_enter_git off
function __empty_enter_list
    commandline --paging-mode; and return
    commandline --search-mode; and return
    test -z "$(commandline)"; or return

    set -l line ls
    __fish_variable_check __fish_empty_enter_git
    if test $status -ne 1; and type -q git
        # Prints "true" only inside a work tree: "false" in .git or a bare
        # repo, an error outside any repo.
        if test "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" = true
            set line 'ls; git status -sb'
        end
    end
    commandline -r -- $line
end
