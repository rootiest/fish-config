# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   13-media-and-utilities
#
# DEPENDENCIES
#   gpg
#
# SYNOPSIS
#   gpg-compact [-K | -k] [pattern...]
#
# DESCRIPTION
#   Lists GPG keys in a compact layout: one line per key and subkey with
#   the algorithm, the short (8-character) key ID, the creation date and
#   the capabilities, followed by the key's user IDs. Lists secret keys by
#   default.
#
#   Keys held on a smartcard (YubiKey, Nitrokey, ...) are marked with ">"
#   after the key type and tagged with the card's serial number, the same
#   number gpg --card-status shows. Secret-key stubs whose private part
#   is offline are marked with "#", as gpg itself does. Expiry dates and
#   revoked or expired keys and user IDs are flagged.
#
#   Colour is used only when stdout is a terminal, and honours NO_COLOR.
#
# ARGUMENTS
#   -K, --secret   List secret keys (the default)
#   -k, --public   List public keys
#   pattern...     Only list keys matching these gpg key specifiers
#                  (key ID, fingerprint, email or name)
#   -h, --help     Show this help message
#
# EXIT STATUS
#   0  Keys listed (an empty keyring lists nothing and still succeeds)
#   1  gpg is missing, or gpg failed, e.g. no key matched a pattern
#   2  Bad usage (unknown option, or both -K and -k)
#
# RETURNS
#   The key listing, printed to stdout
#
# EXAMPLE
#   gpg-compact                  # secret keys, with card serials
#   gpg-compact -k               # public keyring
#   gpg-compact -k alice@example.org
#
# NOTES
#   Short key IDs are for reading, not for trusting: 8 hex digits collide
#   easily. Use the full fingerprint when importing, signing or encrypting.
#
#   Card serials are read from the secret-key listing, so they only appear
#   with -K, and only for keys whose stubs point at a card gpg has seen.
function gpg-compact --description 'List GPG keys compactly with short IDs and smartcard serials'
    __fish_help_header (status current-function) $argv; and return 0
    __fish_palette

    argparse -n gpg-compact -x K,k h/help K/secret k/public -- $argv
    or return
    if set -q _flag_help
        __fish_help_header (status current-function) --help
        return 0
    end

    if not command -q gpg
        echo "$c_err""gpg-compact: gpg is not installed$c_reset" >&2
        return 1
    end

    set -l mode --list-secret-keys
    set -q _flag_public; and set mode --list-keys

    # Colour only for a human reading a terminal: piped output stays plain
    # so it can be grepped. The palette already blanks itself for NO_COLOR.
    set -l on_tty 0
    isatty stdout; and set on_tty 1

    command gpg --batch --quiet --with-colons $mode -- $argv | awk -F: \
        -v tty=$on_tty \
        -v c_type="$c_hi" \
        -v c_uid="$c_arg" \
        -v c_card="$c_accent" \
        -v c_bad="$c_err" \
        -v c_dim="$c_dim" \
        -v c_reset="$c_reset" '
    BEGIN {
        if (!tty) c_type = c_uid = c_card = c_bad = c_dim = c_reset = ""
        keys = 0
    }

    # Algorithm as gpg prints it: the curve name for ECC keys (field 17),
    # otherwise the family plus the key length (field 3).
    function algo_name(   n) {
        if ($17 != "") return $17
        n = $4 + 0
        if (n >= 1 && n <= 3) return "rsa" $3
        if (n == 16 || n == 20) return "elg" $3
        if (n == 17) return "dsa" $3
        return "algo" $4
    }

    # Field 15 of a secret key: "+" means the secret is on disk, "#" a stub
    # with the secret offline, anything else is the serial of the card
    # holding it. An OpenPGP card serial is the 32-hex-digit application ID
    #   D276000124 01 VVVV MMMM SSSSSSSS 0000
    # whose SSSSSSSS is the number the card reports as its serial.
    function card_serial(f) {
        if (f == "" || f == "+" || f == "#") return ""
        if (length(f) == 32 && f ~ /^D276000124/) return substr(f, 21, 8)
        return f
    }

    function day(epoch) {
        return epoch == "" ? "" : strftime("%Y-%m-%d", epoch)
    }

    # Capabilities: lowercase letters belong to this key itself; uppercase
    # ones on a primary key summarise the whole key, so keep the lowercase.
    function caps(f,   out, i, ch) {
        out = ""
        for (i = 1; i <= length(f); i++) {
            ch = substr(f, i, 1)
            if (ch ~ /[escart]/) out = out toupper(ch)
        }
        return out
    }

    function key_line(indent,   serial, marker, extra) {
        serial = card_serial($15)
        marker = serial != "" ? ">" : ($15 == "#" ? "#" : "")
        extra = ""
        if ($2 == "r")
            extra = extra " " c_bad "[revoked]" c_reset
        else if ($2 == "e")
            extra = extra " " c_bad "[expired: " day($7) "]" c_reset
        else if ($7 != "")
            extra = extra " " c_dim "[expires: " day($7) "]" c_reset
        if ($12 ~ /D/)
            extra = extra " " c_bad "[disabled]" c_reset
        if (serial != "")
            extra = extra " " c_card "[card:" serial "]" c_reset
        printf "%s%s%-4s%s  %s/%s %s [%s]%s\n", indent, c_type, $1 marker, c_reset, \
            algo_name(), substr($5, length($5) - 7), day($6), caps($12), extra
    }

    $1 == "sec" || $1 == "pub" {
        if (keys++) print ""
        key_line("")
        next
    }

    $1 == "ssb" || $1 == "sub" {
        key_line("  ")
        next
    }

    # gpg escapes ":" and backslash in user IDs as \x3a and \x5c. Other
    # escapes stay literal: they are control characters, which must not
    # reach the terminal raw. (Fish single quotes halve each backslash pair,
    # so awk sees /\\x3a/: a literal backslash, then x3a.)
    $1 == "uid" {
        uid = $10
        gsub(/\\\\x3a/, ":", uid)
        gsub(/\\\\x5c/, sprintf("%c", 92), uid)
        state = ""
        if ($2 == "r") state = " " c_bad "[revoked]" c_reset
        else if ($2 == "e") state = " " c_bad "[expired]" c_reset
        printf "      %s%s%s%s\n", c_uid, uid, c_reset, state
    }

    END { if (keys) print "" }'

    set -l rc $pipestatus
    if test $rc[1] -ne 0
        return 1
    end
    test $rc[2] -eq 0
end
