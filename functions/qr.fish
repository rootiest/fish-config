# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   10-network
#
# DEPENDENCIES
#   curl, qrencode
#
# CLASSIFICATION
#   self-limiting(cat), network
#
# SYNOPSIS
#   qr [-o | --online] [--] [text...]
#
# DESCRIPTION
#   Generates a UTF-8 QR code from the given text or from stdin if no
#   argument is provided. Encodes locally with qrencode. When qrencode is
#   missing, qr fails with an error rather than sending the text anywhere;
#   pass --online to send it to the qrenco.de API via curl instead.
#
# ARGUMENTS
#   -o, --online  Allow the qrenco.de fallback when qrencode is missing.
#                 The text leaves the machine: avoid it for passwords,
#                 tokens and one-time URLs
#   text...       Text to encode, joined with spaces; reads stdin if omitted
#
# EXIT STATUS
#   0  Success
#   1  qrencode is missing and --online was not given
#   2  Unknown option
#   *  Exit status of qrencode, or of curl with --online
#
# RETURNS
#   The QR code on stdout, drawn with UTF-8 block characters
#
# EXAMPLE
#   qr "https://example.com"
#   echo "hello" | qr
#   qr --online "not a secret"
#
# NOTES
#   Options are only parsed before the first text word; use -- to encode
#   text that itself starts with a dash.
function qr --description 'Generate a QR code from text or pipe'
    __fish_help_header (status current-function) $argv; and return 0

    argparse -s o/online -- $argv
    or return

    # A command substitution does not see the function's piped stdin, so
    # stdin is read through a pipeline into `read -z` (whole input, one
    # value) with the final newline dropped.
    set -l text "$argv"
    if not set -q argv[1]
        cat | read -z text
        set text (string replace -r '\n$' '' -- $text | string collect -a)
    end

    if type -q qrencode
        printf '%s\n' $text | qrencode -t utf8
        return
    end

    if not set -q _flag_online
        __fish_palette
        echo "$c_err""qr: qrencode is not installed; install it, or pass --online to send the text to qrenco.de$c_reset" >&2
        return 1
    end

    if not type -q curl
        __fish_palette
        echo "$c_err""qr: --online needs curl, which is not installed$c_reset" >&2
        return 1
    end

    curl -fsS --max-time 10 "https://qrenco.de/"(string escape --style=url -- $text)
end
