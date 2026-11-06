# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   13-media-and-utilities
#
# DEPENDENCIES
#   gpg, gpg-connect-agent
#
# SYNOPSIS
#   gpg-compact [-K | -k] [-l] [-f] [-a] [pattern...]
#
# DESCRIPTION
#   Lists GPG keys in a compact layout: one line per key and subkey with
#   the algorithm, the short (8-character) key ID, the creation date and
#   the capabilities, followed by the key's user IDs. Lists secret keys by
#   default.
#
#   Keys held on a smartcard (YubiKey, Nitrokey, ...) are marked with ">"
#   after the key type and tagged with the card's serial number, the same
#   number gpg --card-status shows. When a listed key lives on a card, the
#   agent is asked which cards are connected, and keys on a connected card
#   are tagged "inserted"; keys on a card that is not plugged in are
#   dimmed. Secret-key stubs whose private part is offline are marked with
#   "#", as gpg itself does.
#
#   Revoked and expired keys, subkeys and user IDs are hidden unless -a is
#   given; on a terminal, a note on stderr says how many keys were hidden.
#   Expiry dates and disabled keys are flagged.
#
#   Colour is used only when stdout is a terminal, and honours NO_COLOR.
#
# ARGUMENTS
#   -K, --secret        List secret keys (the default)
#   -k, --public        List public keys
#   -l, --long          Show 16-character key IDs instead of 8
#   -f, --fingerprint   Show each primary key's full fingerprint
#   -a, --all           Also show revoked and expired keys and user IDs
#   pattern...          Only list keys matching these gpg key specifiers
#                       (key ID, fingerprint, email or name). Put -- before
#                       a pattern that starts with a dash.
#   -h, --help          Show this help message
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
#   gpg-compact -lf alice@example.org
#   gpg-compact -ka              # include revoked and expired keys
#
# NOTES
#   Short key IDs are for reading, not for trusting: 8 hex digits collide
#   easily. Use the full fingerprint (-f) when importing, signing or
#   encrypting.
#
#   Card serials are read from the secret-key listing, so they only appear
#   with -K, and only for keys whose stubs point at a card gpg has seen.
#   The connected-card check is read-only: it asks the agent for card
#   serial numbers and never writes key stubs, unlike gpg --card-status.
#   It is skipped when no listed key is on a card, and is cut off after 5
#   seconds when timeout is available. Without gpg-connect-agent, card
#   keys are tagged with their serial but not checked.
function gpg-compact --description 'List GPG keys compactly with short IDs and smartcard serials'
    __fish_help_header (status current-function) $argv; and return 0
    __fish_palette

    argparse -n gpg-compact -x K,k h/help K/secret k/public l/long f/fingerprint a/all -- $argv
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

    set -l listing (command gpg --batch --quiet --with-colons $mode -- $argv)
    set -l gpg_rc $status

    # Field 15 of a sec/ssb record is "+", "#", or the serial of the card
    # holding the key. Only ask the agent about cards when there is one.
    set -l checked 0
    set -l inserted
    set -l card_fields (string match -r '^(?:sec|ssb):.*' -- $listing | string split -f15 :)
    if string match -qrv '^[+#]?$' -- $card_fields; and command -q gpg-connect-agent
        set checked 1
        set -l limit
        command -q timeout; and set limit timeout 5
        # "serialno" makes scdaemon pick up a card; "card_list" (gpg 2.3+)
        # then names every connected card, not only the current one.
        set inserted (command $limit gpg-connect-agent 'scd serialno' 'scd getinfo card_list' /bye 2>/dev/null </dev/null |
            string replace -rf '^S SERIALNO (\S+).*' '$1')
    end

    # Colour only for a human reading a terminal: piped output stays plain
    # so it can be grepped. The palette already blanks itself for NO_COLOR.
    set -l on_tty 0
    isatty stdout; and set on_tty 1
    set -l note 0
    isatty stderr; and set note 1

    set -l id_len 8
    set -q _flag_long; and set id_len 16
    set -l show_fpr 0
    set -q _flag_fingerprint; and set show_fpr 1
    set -l show_all 0
    set -q _flag_all; and set show_all 1

    string join \n -- $listing | awk -F: \
        -v tty=$on_tty \
        -v note=$note \
        -v id_len=$id_len \
        -v show_fpr=$show_fpr \
        -v show_all=$show_all \
        -v checked=$checked \
        -v inserted="$inserted" \
        -v c_type="$c_hi" \
        -v c_uid="$c_arg" \
        -v c_card="$c_accent" \
        -v c_bad="$c_err" \
        -v c_dim="$c_dim" \
        -v c_reset="$c_reset" '
    BEGIN {
        if (!tty) c_type = c_uid = c_card = c_bad = c_dim = c_reset = ""
        n = split(inserted, cards, " ")
        for (i = 1; i <= n; i++) present[cards[i]] = 1
        keys = hidden = skip = want_fpr = 0
    }

    function dead() { return $2 == "r" || $2 == "e" }

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
        if (serial != "") {
            if (!checked)
                extra = extra " " c_card "[card:" serial "]" c_reset
            else if ($15 in present)
                extra = extra " " c_card "[card:" serial " inserted]" c_reset
            else
                extra = extra " " c_dim "[card:" serial "]" c_reset
        }
        printf "%s%s%-4s%s  %s/%s %s [%s]%s\n", indent, c_type, $1 marker, c_reset, \
            algo_name(), substr($5, length($5) - id_len + 1), day($6), caps($12), extra
    }

    $1 == "sec" || $1 == "pub" {
        skip = !show_all && dead()
        want_fpr = 0
        if (skip) { hidden++; next }
        if (keys++) print ""
        key_line("")
        want_fpr = show_fpr
        next
    }

    skip { next }

    # The primary key fingerprint is the fpr record right after it.
    $1 == "fpr" {
        if (want_fpr) printf "      %s%s%s\n", c_dim, $10, c_reset
        want_fpr = 0
        next
    }

    $1 == "ssb" || $1 == "sub" {
        want_fpr = 0
        if (!show_all && dead()) { hidden++; next }
        key_line("  ")
        next
    }

    # gpg escapes ":" and backslash in user IDs as \x3a and \x5c. Other
    # escapes stay literal: they are control characters, which must not
    # reach the terminal raw. (Fish single quotes halve each backslash pair,
    # so awk sees /\\x3a/: a literal backslash, then x3a.)
    $1 == "uid" {
        if (!show_all && dead()) next
        uid = $10
        gsub(/\\\\x3a/, ":", uid)
        gsub(/\\\\x5c/, sprintf("%c", 92), uid)
        state = ""
        if ($2 == "r") state = " " c_bad "[revoked]" c_reset
        else if ($2 == "e") state = " " c_bad "[expired]" c_reset
        printf "      %s%s%s%s\n", c_uid, uid, c_reset, state
    }

    END {
        if (keys) print ""
        if (hidden && note)
            printf "%sgpg-compact: %d revoked or expired %s hidden (-a shows them)%s\n", \
                c_dim, hidden, hidden == 1 ? "key" : "keys", c_reset > "/dev/stderr"
    }'
    set -l awk_rc $pipestatus[2]

    test $gpg_rc -eq 0; or return 1
    test $awk_rc -eq 0
end
