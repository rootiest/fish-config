# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_toggle_read_key
#
# DESCRIPTION
#   Reads a single keypress directly from the controlling terminal in raw
#   mode and echoes a normalized token naming the key. Bypasses fish's
#   `read` builtin, whose interactive line editor swallows Tab and arrow
#   keys (and prints a `read> ` prompt) — none of which is usable for a TUI.
#
#   The terminal is put into raw, no-echo mode with a 0.1s inter-byte timer
#   (`stty raw -echo min 1 time 1`) so a multi-byte escape sequence (e.g.
#   an arrow key, ESC [ A) is captured in one read while a lone key returns
#   promptly. Original terminal settings are always restored before return.
#
#   In raw mode Ctrl-C does not raise SIGINT; it arrives as byte 3 (ETX),
#   which is reported as the token "quit".
#
# ARGUMENTS
#   (none)
#
# RETURNS
#   0  A key was read; one of these tokens is printed to stdout:
#        up down left right   arrow keys
#        space tab enter escape
#        quit                 Ctrl-C (byte 3) in raw mode
#        <char>               any other single printable character
#        ""                   nothing decodable was read
#   1  The terminal could not be put into raw mode (stdin is not a TTY)
#
# EXAMPLE
#   set -l key (__config_toggle_read_key)
#   or return                       # not a TTY — bail
#   switch $key
#       case up;    echo "moved up"
#       case space; echo "toggled"
#   end
function __config_toggle_read_key
    # Snapshot current terminal settings; failure means stdin is not a TTY.
    set -l saved (stty -g </dev/tty 2>/dev/null)
    or return 1

    # Raw, no-echo. min 0 / time 3: return after 0.3s even with no bytes (poll
    # interval for resize detection), or immediately when any bytes arrive.
    # Escape sequences (e.g. arrow keys) arrive fast enough to land in one read.
    stty raw -echo min 0 time 3 </dev/tty 2>/dev/null

    # One read() of up to 3 bytes — covers ESC [ A style sequences. od emits
    # the bytes as space-separated decimal codes.
    set -l codes (dd if=/dev/tty bs=3 count=1 2>/dev/null \
        | od -An -tu1 2>/dev/null | string trim | string split -n ' ')

    # Restore the terminal before doing anything else.
    stty $saved </dev/tty 2>/dev/null

    switch (string join ' ' $codes)
        case '27 91 65'
            echo up
        case '27 91 66'
            echo down
        case '27 91 67'
            echo right
        case '27 91 68'
            echo left
        case 27
            echo escape
        case 9
            echo tab
        case 32
            echo space
        case 10 13
            echo enter
        case 3
            echo quit
        case ''
            echo ''
        case '*'
            # Single printable byte → emit its character; ignore stray
            # multi-byte sequences we do not recognise. The two-step octal
            # form avoids fish mangling a one-shot '\\%03o' format string.
            if test (count $codes) -eq 1
                set -l oct (printf '%03o' $codes[1])
                printf '%b\n' "\\$oct"
            else
                echo ''
            end
    end
end
