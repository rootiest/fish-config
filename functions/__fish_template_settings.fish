# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_settings FILE
#
# DESCRIPTION
#   Prints one line per setting of template FILE, in file order:
#   KEY<TAB>TYPE<TAB>REQUIRED<TAB>PROMPT. A setting is a `set -l` line
#   before the first Fragment banner; its prompt is the comment line right
#   above it, minus a trailing type hint such as `(int)`, `(list, required)`
#   or `(choice: a b)`. No hint means TYPE text and REQUIRED 0.
#
# EXIT STATUS
#   0  Always
function __fish_template_settings --argument-names file --description 'List the settings of a fish-template template'
    set -l prev
    while read -l line
        string match -qr -- '^#\s+─+ Fragment' $line; and break
        set -l key (string match -r --groups-only -- '^set -l ([a-z][a-z0-9_]*)(?:\s|$)' $line)
        if set -q key[1]
            set -l prompt (string replace -r -- '^#\s*' '' "$prev")
            set -l hint (string match -r --groups-only -- '\(([^()]*)\)$' $prompt)
            set -l type text
            set -l req 0
            if set -q hint[1]
                set prompt (string replace -r -- '\s*\([^()]*\)$' '' $prompt)
                for h in (string split -n ', ' -- $hint)
                    if test "$h" = required
                        set req 1
                    else
                        set type (string replace -r -- '^choice:\s*' 'choice:' $h)
                    end
                end
            end
            printf '%s\t%s\t%s\t%s\n' $key[1] $type $req "$prompt"
        end
        set prev $line
    end <$file
    return 0
end
