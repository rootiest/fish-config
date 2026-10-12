# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_names [target|modifier|preset]
#
# DESCRIPTION
#   Prints template names of one kind, one per line, sorted. With no kind,
#   prints the targets and then the modifiers.
#
# EXIT STATUS
#   0  Success
#   2  Unknown kind
function __fish_template_names --argument-names kind --description 'List fish-template template names'
    set -l root (__fish_template_dir)
    set -l dirs
    switch "$kind"
        case target
            set dirs $root/targets
        case modifier
            set dirs $root/modifiers
        case preset
            set dirs $root/presets
        case ''
            set dirs $root/targets $root/modifiers
        case '*'
            return 2
    end
    for d in $dirs
        for f in $d/*.fish
            path change-extension '' (path basename -- $f)
        end
    end
    return 0
end
