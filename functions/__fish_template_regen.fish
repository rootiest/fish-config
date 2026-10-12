# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   bypasses-shadow(rm)
#
# SYNOPSIS
#   __fish_template_regen [--all] [-o DIR] NAME...
#
# DESCRIPTION
#   Rebuilds functions made by fish-template from their embedded recipes
#   against the current templates, without asking anything. Settings the
#   templates gained take their defaults; settings they lost are dropped
#   with a warning. Only files carrying the recipe marker are touched.
#
# EXIT STATUS
#   0  Every function was rebuilt
#   1  At least one could not be
#   2  Usage error
function __fish_template_regen --description 'Rebuild functions made by fish-template'
    argparse all 'o/output=' -- $argv; or return 2
    __fish_palette
    set -l outdir (__fish_user_dots_dir)/functions
    set -q _flag_output; and set outdir $_flag_output
    set -l names $argv
    set -q _flag_all; and set names (__fish_template_generated $outdir)
    if not set -q names[1]
        if set -q _flag_all
            echo "No functions made by fish-template in $outdir."
            return 0
        end
        echo "$c_err""fish-template: regen needs function names or --all$c_reset" >&2
        echo "Run $c_cmd""fish-template help$c_reset for usage." >&2
        return 2
    end
    set -l failed 0
    for n in $names
        set -l file (__fish_template_locate $n $outdir)
        if test -z "$file"
            set failed 1
            continue
        end
        __fish_template_store reset
        __fish_template_store load $file
        if not __fish_template_validate
            set failed 1
            continue
        end
        set -l tmp (mktemp)
        if test -z "$tmp"; or not __fish_template_assemble $n >$tmp
            echo "$c_err""fish-template: could not assemble $n; it was left unchanged$c_reset" >&2
            test -n "$tmp"; and command rm -f -- $tmp
            set failed 1
            continue
        end
        __fish_template_write --managed $n $tmp (path dirname -- $file); or set failed 1
        command rm -f -- $tmp
    end
    __fish_template_store reset
    test $failed -eq 0
end
