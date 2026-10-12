# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   bypasses-shadow(rm)
#
# SYNOPSIS
#   __fish_template_new [--edit] [OPTIONS] [NAME]
#
# DESCRIPTION
#   The new and edit flows of fish-template (see its OPTIONS). Values are
#   layered in this order: an edited function's recipe, --preset (defaults
#   the wizard offers), --from (given, never asked), --target/--with, then
#   --set (given). Without --yes, the wizard asks for everything not given,
#   then offers a preview and asks before writing.
#
# EXIT STATUS
#   0  Written (or printed with --dry-run)
#   1  Refused, cancelled or failed
#   2  Usage error or invalid recipe
function __fish_template_new --description 'Create or edit a function with fish-template'
    argparse edit 't/target=' 'w/with=+' 's/set=+' 'f/from=' 'p/preset=' 'o/output=' n/dry-run y/yes force -- $argv
    or return 2
    __fish_palette
    set -l usage "Run $c_cmd""fish-template help$c_reset for usage."
    set -l outdir (__fish_user_dots_dir)/functions
    set -q _flag_output; and set outdir $_flag_output

    if set -q argv[2]
        echo "$c_err""fish-template: expected one function name, got: $argv$c_reset" >&2
        echo $usage >&2
        return 2
    end
    if set -q _flag_from; and set -q _flag_preset
        echo "$c_err""fish-template: use --from or --preset, not both$c_reset" >&2
        echo $usage >&2
        return 2
    end
    set -l name $argv[1]
    if test -n "$name"; and not string match -qr '^[A-Za-z0-9_][A-Za-z0-9_.+-]*$' -- $name
        echo "$c_err""fish-template: '$name' is not a valid function name$c_reset" >&2
        return 2
    end
    # Names that pass the regex can still be fish keywords or builtins that
    # fish refuses to define as functions (set, end, test, ...).
    if test -n "$name"; and not __fish_template_name_ok $name
        echo "$c_err""fish-template: '$name' is a reserved word in fish and cannot be a function name$c_reset" >&2
        return 2
    end

    __fish_template_store reset
    set -l write_flags
    set -q _flag_force; and set write_flags --force
    if set -q _flag_edit
        if test -z "$name"
            echo "$c_err""fish-template: edit needs a function name$c_reset" >&2
            echo $usage >&2
            return 2
        end
        set -l file (__fish_template_locate $name $outdir); or return 1
        __fish_template_store load $file
        set outdir (path dirname -- $file)
        set write_flags --managed
    end
    if set -q _flag_preset
        set -l preset (__fish_template_file --preset $_flag_preset)
        if test -z "$preset"
            echo "$c_err""fish-template: unknown preset '$_flag_preset' (see: fish-template list)$c_reset" >&2
            return 2
        end
        __fish_template_store load $preset
    end
    if set -q _flag_from; and not __fish_template_store load --mark $_flag_from
        echo "$c_err""fish-template: cannot read $_flag_from$c_reset" >&2
        return 2
    end

    set -l target $__ftv___ft_use[1]
    set -l mods $__ftv___ft_use[2..]
    set -l ask_target --ask-target
    set -l ask_mods --ask-mods
    if __fish_template_store marked __ft_use
        set ask_target
        set ask_mods
    end
    if set -q _flag_target
        set target $_flag_target
        set ask_target
    end
    if set -q _flag_with
        for m in (string split -n , -- $_flag_with)
            contains -- $m $mods; or set -a mods $m
        end
        set ask_mods
    end

    set -l seen
    for kv in $_flag_set
        set -l pair (string split -m1 = -- $kv)
        if not set -q pair[2]
            echo "$c_err""fish-template: --set needs KEY=VALUE, got '$kv'$c_reset" >&2
            return 2
        end
        set -l info (__fish_template_key_info $pair[1])
        if test -z "$info"
            echo "$c_err""fish-template: unknown setting '$pair[1]' (see: fish-template info TEMPLATE)$c_reset" >&2
            return 2
        end
        set -l vals
        switch (string split -f3 \t -- $info)
            case list
                printf '%s\n' $pair[2] | read -at vals
            case lines
                set -l v __ftv_$pair[1]
                contains -- $pair[1] $seen; and set vals $$v
                set -a vals $pair[2]
            case '*'
                set vals $pair[2]
        end
        __fish_template_store set --mark $pair[1] $vals
        set -a seen $pair[1]
    end

    if set -q _flag_yes
        if test -z "$name"
            echo "$c_err""fish-template: --yes needs a function name$c_reset" >&2
            echo $usage >&2
            return 2
        end
        __fish_template_store set __ft_use $target $mods
    else
        set -l ask_name
        test -z "$name"; and set ask_name --ask-name
        if not __fish_template_wizard $ask_name $ask_target $ask_mods -- $target $mods
            echo "Cancelled; nothing was written." >&2
            __fish_template_store reset
            return 1
        end
        test -z "$name"; and set name $__ftv___ft_name
    end

    if not __fish_template_validate
        __fish_template_store reset
        return 2
    end
    set -l tmp (mktemp); or return 1
    __fish_template_assemble $name >$tmp
    if set -q _flag_dry_run
        string collect -N <$tmp
        command rm -f -- $tmp
        __fish_template_store reset
        return 0
    end
    if not set -q _flag_yes
        set -l ans
        read -P "Preview the function? [Y/n] " ans; or set ans n
        string match -qir '^n' -- "$ans"; or string collect -N <$tmp
        read -P "Write $outdir/$name.fish? [Y/n] " ans; or set ans n
        if string match -qir '^n' -- "$ans"
            echo "Nothing written." >&2
            command rm -f -- $tmp
            __fish_template_store reset
            return 1
        end
    end
    __fish_template_write $write_flags $name $tmp $outdir
    set -l st $status
    command rm -f -- $tmp
    __fish_template_store reset
    return $st
end
