# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   bypasses-shadow(chmod,grep)
#
# SYNOPSIS
#   _agents_vault_ensure_gitignore <vault>
#
# DESCRIPTION
#   Makes sure the vault's .gitignore carries the rules agents-vault
#   depends on. They keep a SQLite database (and its write-ahead log and
#   shared-memory sidecars) and the stash directories --adopt and the slug
#   migration fall back to out of every `git add -A`, so a vault missing
#   one will eventually commit something it must not.
#
#   An absent file is created from the full template with mode 600. An
#   existing file is merged: every line the user has is left exactly as it
#   is, in place, and only the required rules that are not already present
#   as a whole line are appended, as one commented block at the end. A
#   file that already carries them all is not touched, so running this on
#   every launch is idempotent and leaves no diff.
#
#   Presence is a whole-line comparison, not git check-ignore. The vault
#   travels between machines, so the file has to be self-sufficient: a rule
#   that happens to be covered by one machine's global excludes file must
#   still be written down here. This is the one deliberate difference from
#   _agents_init_ensure_gitignore, whose job is a project's .gitignore that
#   is read on the machine that wrote it.
#
# ARGUMENTS
#   vault  Vault root
#
# EXIT STATUS
#   0  The file was already complete, or was created or merged
#   1  The file could not be written
#
# RETURNS
#   "created" or "merged" on stdout when the file was written, nothing when
#   it was already complete.
#
# EXAMPLE
#   _agents_vault_ensure_gitignore $vault
function _agents_vault_ensure_gitignore
    set -l vault $argv[1]
    test -n "$vault"; or return 1
    set -l gi "$vault/.gitignore"

    # Create from the full, commented template.
    if not test -e "$gi"
        printf '%s\n' \
            '# A SQLite database and its sidecars are never safe to commit' \
            '# mid-write. Ignoring only the sidecars is worse than ignoring' \
            '# none of them: a torn database then lands in the history with' \
            '# the write-ahead log that would have completed it excluded.' \
            '*.db' \
            '*.db-wal' \
            '*.db-shm' \
            '' \
            '# --adopt and the slug migration each stash the entry they are' \
            '# about to overwrite inside .git/, out of reach of `git add -A`.' \
            '# These cover the fallback locations they use when .git is not a' \
            '# directory.' \
            '/.adopt-stash' \
            '/.migrate-stash' >"$gi"
        or return 1
        command chmod 600 "$gi"
        echo created
        return 0
    end

    # Merge into an existing file: append only what is missing. Anything
    # that is not a regular file (a directory, say) cannot be merged into.
    test -f "$gi"; or return 1
    set -l missing
    for rule in '*.db' '*.db-wal' '*.db-shm' /.adopt-stash /.migrate-stash
        command grep -qxF -- "$rule" "$gi" 2>/dev/null; or set -a missing "$rule"
    end
    test (count $missing) -gt 0; or return 0

    # The leading blank line also terminates a last line that lacks its
    # newline, so the block never fuses with the user's final rule.
    begin
        printf '\n%s\n' \
            '# Added by agents-vault: rules the vault relies on. A SQLite' \
            '# database and its sidecars, and the stash directories --adopt' \
            '# and the slug migration fall back to, must never be committed.'
        printf '%s\n' $missing
    end >>"$gi"
    or return 1
    echo merged
end
