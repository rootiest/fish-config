# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   _mkrep_say, __fish_palette, git
#
# SYNOPSIS
#   _mkrep_add_origin <silent> <url>
#
# DESCRIPTION
#   Links origin to <url>, idempotently, for mkrep's --remote and --server
#   link-existing flows. Both can run against a directory that is already a
#   repo -- `mkrep .` on an existing checkout, or a second mkrep against the
#   same target -- where a bare `git remote add origin` fails with "remote
#   origin already exists" and takes the whole call down with it.
#
#   No origin yet: adds it. An origin already pointing at <url>: reports that
#   and succeeds, since the requested end state already holds. An origin
#   pointing somewhere else: refuses, naming both URLs. Repointing is not
#   silently assumed -- an origin the caller did not ask about is more likely
#   a checkout mkrep was aimed at by mistake than one it should rewrite, so
#   the fix belongs in the caller's hands (git remote set-url origin <url>).
#
# ARGUMENTS
#   silent  1 to suppress the success/already-linked notes (mkrep's -s)
#   url     Remote URL origin should point at
#
# EXIT STATUS
#   0  origin now points at <url> (added, or already did)
#   1  git remote add failed, or origin points somewhere else
function _mkrep_add_origin --argument-names silent url
    __fish_palette

    set -l existing (git remote get-url origin 2>/dev/null)

    if test -z "$existing"
        git remote add origin $url
        or begin
            echo "$c_err""✘$c_reset  Failed to add remote $c_arg$url$c_reset" >&2
            return 1
        end
        _mkrep_say $silent "$c_ok""✔$c_reset  Linked remote $c_arg$url$c_reset"
        return 0
    end

    if test "$existing" = "$url"
        _mkrep_say $silent "$c_warn""→$c_reset  origin already points at $c_arg$url$c_reset"
        return 0
    end

    echo "$c_err""✘$c_reset  origin already points at $c_arg$existing$c_reset, not $c_arg$url$c_reset — run $c_cmd""git remote set-url origin $url$c_reset to repoint it" >&2
    return 1
end
