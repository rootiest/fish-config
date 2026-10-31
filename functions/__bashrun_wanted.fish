# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __bashrun_wanted <fish-validity> <text>
#
# DESCRIPTION
#   Decides whether a command line Fish rejected should run through Bash
#   instead. <fish-validity> is the status of `commandline --is-valid`:
#   0 valid, 1 a syntax error, 2 incomplete.
#
#   Valid Fish never goes to Bash. A syntax error goes when `bash -n`
#   accepts the text. An incomplete line also needs a Bash block closer
#   (done, fi, esac) in command position or a heredoc, because a Fish block
#   still being typed (`begin`, `for x in a b`) is valid Bash too.
#
# EXIT STATUS
#   0  Run it through Bash
#   1  Leave it to Fish
#
# EXAMPLE
#   __bashrun_wanted 2 'for f in *; do echo $f; done'
function __bashrun_wanted
    set -l validity $argv[1]
    set -l text "$argv[2..-1]"
    test "$validity" = 1 -o "$validity" = 2; or return 1
    string match -qr -- '\S' $text; or return 1
    type -q bash; or return 1

    if test "$validity" = 2
        string match -qr -- '(^|[;&|(\n]\s*)(done|fi|esac)\b|<<' $text; or return 1
    end
    command bash -n -c $text 2>/dev/null
end
