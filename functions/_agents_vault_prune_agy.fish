# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   destructive
#
# SYNOPSIS
#   _agents_vault_prune_agy <vault> <knowledge>
#
# DESCRIPTION
#   Mirrors deletions from agy's knowledge store into the vault. The copy
#   in agents-vault only ever adds files, so a note deleted upstream would
#   stay in global/agy/knowledge/ and be re-committed forever; this removes
#   every vault file under that one directory that the copy would not have
#   produced from the current store.
#
#   "Would have produced" is decided file by file against the same rules
#   the copy walk applies: the name ends in .md or .json, no path component
#   is dot-led, and the source is a regular file reached through no symlink
#   (its own path resolves to itself). rsync --delete is deliberately not
#   used: its filter language cannot express "do not follow a symlinked
#   directory" together with the extension allowlist, and a second
#   implementation of the allowlist that disagrees with the copy by one
#   case is how the earlier dereference bug got in.
#
#   Scope is the vault's global/agy/knowledge directory and nothing else.
#   The function refuses outright if that directory, or the global/agy and
#   global directories above it, is a symlink or does not resolve to where
#   it should, and find is never allowed to follow a link, so a planted
#   link cannot aim a deletion outside it. A symlink found inside the
#   mirror is removed as a link, never followed.
#
#   Two guards stop an absent or empty source from wiping the backup. The
#   source must be a readable directory, and if not one single vault file
#   has a counterpart in it the function removes nothing: an unmounted
#   store, an emptied directory and a store that cannot be read all look
#   like that, and none of them is evidence that the knowledge was deleted
#   on purpose. The cost is that deleting the very last note upstream does
#   not prune it; remove it from the vault by hand.
#
#   Directories left empty by the pruning are removed too, since git does
#   not track them and they would only linger on disk.
#
# ARGUMENTS
#   vault      Vault root (the git repository)
#   knowledge  agy's knowledge directory (the source of truth)
#
# EXIT STATUS
#   0  Mirror is current (nothing, or only stale files, were removed)
#   1  A stale file could not be removed
#   2  Refused: a path was not what it must be, or the source had no
#      counterpart for any vault file; nothing was removed
#
# RETURNS
#   The number of files removed, one line on stdout, only on exit 0 or 1.
#
# EXAMPLE
#   _agents_vault_prune_agy $vault ~/.gemini/antigravity-cli/knowledge
function _agents_vault_prune_agy
    test (count $argv) -eq 2; or return 2
    set -l vault $argv[1]
    set -l knowledge $argv[2]
    set -l vk "$vault/global/agy/knowledge"

    # Nothing mirrored yet means nothing to prune.
    test -d "$vk"; or begin
        echo 0
        return 0
    end

    # The mirror must be a real directory at the real place. Checked
    # component by component because a link at any of them would send the
    # deletion somewhere else.
    for p in "$vault/global" "$vault/global/agy" "$vk"
        test -L "$p"; and return 2
    end
    test (path resolve "$vk") = (path resolve "$vault")/global/agy/knowledge; or return 2

    # The source must be a readable directory; otherwise absence is not
    # evidence of anything.
    test -d "$knowledge"; and test -r "$knowledge"; or return 2
    set -l kres (path resolve "$knowledge")

    # One verdict per vault file, in walk order: 1 when the copy would have
    # produced it from the current store, 0 when it is stale. The rules are
    # the copy walk's own -- see DESCRIPTION. The verdicts come out of the
    # command substitution as a list because nothing set inside one can be
    # read back, and the removal below indexes into them.
    set -l files (command find "$vk" -mindepth 1 ! -type d -print0 2>/dev/null | string split0)
    test (count $files) -gt 0; or begin
        echo 0
        return 0
    end
    set -l verdicts (for f in $files
        set -l rel (string replace -- "$vk/" "" "$f")
        set -l src "$kres/$rel"
        if string match -qr '(^|/)\.' -- "$rel"
            echo 0
        else if not string match -qr '\.(md|json)$' -- "$rel"
            echo 0
        else if test -f "$src"; and test (path resolve "$src") = "$src"
            echo 1
        else
            echo 0
        end
    end)

    # The empty/unmounted-source guard: with no survivors at all, removing
    # everything is indistinguishable from a source that is simply not
    # there, so nothing is removed.
    contains -- 1 $verdicts; or return 2

    set -l removed 0
    set -l failed 0
    for i in (seq (count $files))
        test "$verdicts[$i]" = 1; and continue
        if command rm -f -- "$files[$i]"
            set removed (math $removed + 1)
        else
            set failed 1
        end
    end
    command find "$vk" -mindepth 1 -type d -empty -delete 2>/dev/null

    echo $removed
    test $failed -eq 0
end
