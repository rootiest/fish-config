# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   fzf
#
# SYNOPSIS
#   __fish_template_wizard [--ask-name] [--ask-target] [--ask-mods] -- [TARGET [MOD...]]
#
# DESCRIPTION
#   The interactive part of fish-template new/edit. Asks, in order, for
#   the function name, the target and the modifiers (each only when told
#   to; TARGET and MODs are the current choice and the defaults), then for
#   every setting of the chosen templates that is not marked as given.
#   Answers go to the store (__ft_name, __ft_use, settings). Reads one line
#   per answer from stdin, so scripts can pipe answers in. The target is
#   picked with fzf when it is installed and stdin is a terminal.
#
# EXIT STATUS
#   0  Done
#   1  End of input, or the fzf picker was cancelled
function __fish_template_wizard --description 'Ask the fish-template questions'
    argparse ask-name ask-target ask-mods -- $argv; or return 2
    set -l target $argv[1]
    set -l mods $argv[2..]

    if set -q _flag_ask_name
        while true
            set -l ans
            read -P "Function name: " ans; or return 1
            if not string match -qr '^[A-Za-z0-9_][A-Za-z0-9_.+-]*$' -- $ans
                echo "  Use letters, digits, _ . + and - (not first)." >&2
                continue
            end
            if not __fish_template_name_ok $ans
                echo "  '$ans' is a reserved word in fish; choose another name." >&2
                continue
            end
            __fish_template_store set __ft_name $ans
            break
        end
    end

    if set -q _flag_ask_target
        set -l targets (__fish_template_names target)
        if isatty stdin; and command -q fzf
            set -l pick (for t in $targets
                    printf '%s\t%s\n' $t (__fish_template_meta (__fish_template_file $t) SUMMARY)
                end | fzf --delimiter=\t --prompt='Target> ' --height=40% --reverse | string split -f1 \t)
            test -n "$pick"; or return 1
            set target $pick
        else
            while true
                set -l ans
                read -P "Target ($(string join / -- $targets)) [$target]: " ans; or return 1
                test -z "$ans"; and set ans $target
                if contains -- "$ans" $targets
                    set target $ans
                    break
                end
                echo "  Choose one of: $targets" >&2
            end
        end
    end

    if set -q _flag_ask_mods
        set -l allowed
        for m in (__fish_template_names modifier)
            contains -- $target (string split -n ' ' -- (__fish_template_meta (__fish_template_file $m) APPLIES))
            and set -a allowed $m
        end
        while true
            set -l ans
            read -P "Modifiers (space-separated; ? lists them; - for none) [$mods]: " ans; or return 1
            if test "$ans" = '?'
                for m in $allowed
                    printf '  %-10s %s\n' $m "$(__fish_template_meta (__fish_template_file $m) SUMMARY)"
                end
                continue
            end
            test -z "$ans"; and break
            if test "$ans" = -
                set mods
                break
            end
            set -l picked (string split -n ' ' -- $ans)
            set -l bad
            for m in $picked
                contains -- $m $allowed; or set -a bad $m
            end
            if set -q bad[1]
                echo "  Not available for $target: $bad (? lists them)" >&2
                continue
            end
            set mods $picked
            break
        end
    end
    __fish_template_store set __ft_use $target $mods

    for t in $target $mods
        set -l f (__fish_template_file $t); or continue
        __fish_template_store load --defaults $f
        for row in (__fish_template_settings $f)
            set -l c (string split \t -- $row)
            __fish_template_store marked $c[1]; and continue
            __fish_template_prompt $t $c[1] $c[2] $c[3] "$c[4]"; or return 1
        end
    end
    return 0
end
