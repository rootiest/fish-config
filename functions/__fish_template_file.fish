# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_file [--preset] NAME
#
# DESCRIPTION
#   Prints the path of template NAME (templates/targets/ or
#   templates/modifiers/), or of preset NAME with --preset. NAME must be
#   lowercase letters, digits and dashes, so it can never escape the
#   templates directory.
#
# EXIT STATUS
#   0  Found
#   1  No such template or preset, or an invalid name
function __fish_template_file --description 'Print the path of a fish-template template'
    argparse preset -- $argv; or return 2
    string match -qr '^[a-z][a-z0-9-]*$' -- "$argv[1]"; or return 1
    set -l root (__fish_template_dir)
    set -l dirs $root/targets $root/modifiers
    set -q _flag_preset; and set dirs $root/presets
    for d in $dirs
        if test -f $d/$argv[1].fish
            echo $d/$argv[1].fish
            return 0
        end
    end
    return 1
end
