# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_validate
#
# DESCRIPTION
#   Checks the recipe in the store before assembly. __ft_use must name one
#   target followed by distinct modifiers whose APPLIES list includes that
#   target. Every used template's defaults are filled in, then every
#   setting is checked and normalized (__fish_template_check). Settings
#   that belong to no used template are dropped with a warning. Finally,
#   confirm_only_if must be a valid regular expression, each
#   dispatcher_subcommands entry must be name=command line,
#   dispatcher_default must name one of them, each perhost_commands and
#   peros_commands entry must be key=command line, a {@} slot in
#   snippet_cmd must be a word of its own, and each env_set entry must be
#   NAME=value. env_unset needs a command, fallback or snippet target.
#   Errors go to stderr, prefixed "fish-template:".
#
# EXIT STATUS
#   0  The recipe is valid
#   2  It is not
function __fish_template_validate --description 'Validate a fish-template recipe'
    set -l use $__ftv___ft_use
    if not set -q use[1]
        echo "fish-template: no target chosen (see: fish-template list)" >&2
        return 2
    end
    set -l tfile (__fish_template_file $use[1])
    if test -z "$tfile"; or test "$(__fish_template_meta $tfile KIND)" != target
        echo "fish-template: unknown target '$use[1]' (see: fish-template list)" >&2
        return 2
    end
    set -l files $tfile
    set -l seen
    for m in $use[2..]
        set -l f (__fish_template_file $m)
        if test -z "$f"; or test "$(__fish_template_meta $f KIND)" != modifier
            echo "fish-template: unknown modifier '$m' (see: fish-template list)" >&2
            return 2
        end
        if contains -- $m $seen
            echo "fish-template: modifier '$m' is listed twice" >&2
            return 2
        end
        if not contains -- $use[1] (string split -n ' ' -- (__fish_template_meta $f APPLIES))
            echo "fish-template: $m cannot be used with a $use[1] target" >&2
            return 2
        end
        set -a seen $m
        set -a files $f
    end
    if not contains -- $use[1] command fallback snippet; and set -q __ftv_env_unset[1]
        echo "fish-template: env_unset needs a command, fallback or snippet target" >&2
        return 2
    end

    set -l known __ft_use __ft_name
    set -l failed 0
    for f in $files
        __fish_template_store load --defaults $f
        for row in (__fish_template_settings $f)
            set -l c (string split \t -- $row)
            set -a known $c[1]
            set -l v __ftv_$c[1]
            set -l norm (__fish_template_check $c[1] $c[2] $c[3] $$v)
            if test $status -eq 0
                __fish_template_store set $c[1] $norm
            else
                set failed 1
            end
        end
    end
    for k in (set -gn | string match -r --groups-only '^__ftv_(.+)$')
        contains -- $k $known; and continue
        echo "fish-template: ignoring unknown setting $k" >&2
        set -eg __ftv_$k __ftm_$k
    end

    #   ── Settings whose format the type alone cannot check ──
    if test -n "$__ftv_confirm_only_if[1]"
        string match -qr -- $__ftv_confirm_only_if[1] '' 2>/dev/null
        if test $status -eq 2
            echo "fish-template: confirm_only_if: not a valid regular expression" >&2
            set failed 1
        end
    end
    for e in $__ftv_dispatcher_subcommands
        if not string match -qr -- '^[^=[:space:]]+=.+' $e
            echo "fish-template: dispatcher_subcommands: '$e' is not name=command line" >&2
            set failed 1
        end
    end
    if test -n "$__ftv_dispatcher_default[1]"
        set -l subs (string replace -r -- '=.*' '' $__ftv_dispatcher_subcommands)
        if not contains -- $__ftv_dispatcher_default[1] $subs
            echo "fish-template: dispatcher_default: '$__ftv_dispatcher_default[1]' is not one of the subcommands ($subs)" >&2
            set failed 1
        end
    end
    for k in perhost_commands peros_commands
        set -l v __ftv_$k
        for e in $$v
            if not string match -qr -- '^[^=[:space:]]+=.+' $e
                echo "fish-template: $k: '$e' is not key=command line" >&2
                set failed 1
            end
        end
    end
    for w in $__ftv_snippet_cmd
        if test "$w" != '{@}'; and string match -q -- '*{@}*' $w
            echo "fish-template: snippet_cmd: {@} must be a word of its own, got '$w'" >&2
            set failed 1
        end
    end
    for e in $__ftv_env_set
        if not string match -qr -- '^[A-Za-z_][A-Za-z0-9_]*=' $e
            echo "fish-template: env_set: '$e' is not NAME=value" >&2
            set failed 1
        end
    end
    test $failed -eq 0; or return 2
    return 0
end
