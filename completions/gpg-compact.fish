# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for gpg-compact.
#
# Positionals are gpg key specifiers, never files: offer the email address
# and long key ID of every key in the keyring, described by its first name.

complete -c gpg-compact -f
complete -c gpg-compact -s h -l help -d 'Show help message'
complete -c gpg-compact -s K -l secret -d 'List secret keys (default)'
complete -c gpg-compact -s k -l public -d 'List public keys'
complete -c gpg-compact -s l -l long -d 'Show 16-character key IDs'
complete -c gpg-compact -s f -l fingerprint -d 'Show primary key fingerprints'
complete -c gpg-compact -s a -l all -d 'Include revoked and expired keys'
complete -c gpg-compact -a '(__gpg_compact_complete_keys)'

# Empty (and harmless) when gpg is missing or the keyring is empty.
function __gpg_compact_complete_keys
    type -q gpg; or return 0
    command gpg --batch --list-keys --with-colons 2>/dev/null | awk -F: '
        $1 == "pub" { id = $5; named = 0 }
        $1 == "uid" && $2 != "r" {
            uid = $10
            gsub(/\\\\x3a/, ":", uid)
            name = uid
            sub(/ *<.*$/, "", name)
            if (match(uid, /<[^>]+>/))
                printf "%s\t%s\n", substr(uid, RSTART + 1, RLENGTH - 2), name
            if (!named++) printf "%s\t%s\n", id, name
        }'
    return 0
end
