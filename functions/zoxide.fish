# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
# Adapted from icezyclon/zoxide.fish (MIT)
# Heavily customized for Fish 4.x compatibility and performance

# CATEGORY
#   02-navigation
#
# INTERNAL SYNOPSIS
#   _zoxide_z_complete [comp] [desc]
#
# DESCRIPTION
#   Tab-completion handler for z/cd that merges standard filesystem completions
#   (CWD, CDPATH) with zoxide frecency results. Called automatically by Fish
#   during tab completion; not invoked directly.
#
# ARGUMENTS
#   comp  Currently completing token (read from commandline if omitted)
#   desc  Unused description argument
#
# EXAMPLE
#   # Fired automatically during tab completion.
#   z my<TAB>
function _zoxide_z_complete -d "Complete directory first or zoxide queries otherwise" --argument-names comp desc
    # comp is the currently completing token
    if not set -q comp[1]
        set comp (commandline -ct)
    end
    # cmd are all tokens including the current one except the command
    set -l cmd (commandline -opc) $comp
    set -e cmd[1]

    # 1. Get standard completions (CWD, CDPATH, etc.)
    # We call the underlying functions directly to avoid recursion.
    if test (count $cmd) -le 1
        # CDPATH results
        __fish_complete_cd
        # Local directory results (CWD)
        __fish_complete_directories "$comp" ""
    end

    # 2. Get zoxide results
    # Cap results to 25 to avoid overwhelming the completion engine
    set -l zresults (zoxide query -l $cmd | head -n 25)
    for res in $zresults
        set -l bname (basename $res)
        # If the basename matches the prefix, show it as a short name.
        if string match -qi "$comp*" -- $bname
            printf "%s/\tzoxide: %s\n" $bname $res
        end
        # Also provide the absolute path. Fish will filter it if it doesn't match.
        printf "%s/\tzoxide\n" $res
    end
end

# CATEGORY
#   02-navigation
#
# INTERNAL SYNOPSIS
#   _zoxide_equals_first_token <check>
#
# DESCRIPTION
#   Tests whether the first non-switch token on the commandline equals the
#   given string. Used internally to guard zoxide completion sources.
#
# ARGUMENTS
#   check  The string to compare against the first non-switch token
#
# EXIT STATUS
#   0  First token equals check
#   1  No token or token does not match
#
# EXAMPLE
#   _zoxide_equals_first_token z
function _zoxide_equals_first_token -a check -d "Test if first non-switch token equals given one"
    set -l tokens (commandline -co)
    set -e tokens[1]
    set -l tokens (string replace -r --filter '^([^-].*)' '$1' -- $tokens)
    if set -q tokens[1]
        test $tokens[1] = $check
    else
        return 1
    end
end
