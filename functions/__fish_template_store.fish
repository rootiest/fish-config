# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_store reset
#   __fish_template_store set [--mark] KEY [VALUE...]
#   __fish_template_store get|has|marked|emit KEY
#   __fish_template_store load [--mark] [--defaults] FILE
#
# DESCRIPTION
#   fish-template's value store: one global per setting (__ftv_KEY) plus a
#   mark (__ftm_KEY) for settings the user gave explicitly, which the
#   wizard then skips. Other helpers may read $__ftv_KEY directly.
#
#   emit prints KEY as a `set -l KEY VALUE...` line with every value
#   string-escaped; load reads such lines back exactly. load tokenizes with
#   `read --tokenize`, which honors quotes and escapes but never expands
#   $, (...) or ~, so a recipe or setup file is never executed. In a
#   generated function only the lines between the recipe markers are read;
#   in a template, only those before the first Fragment banner. --defaults
#   skips keys that already have a value.
#
# EXIT STATUS
#   0  Success; for has/marked, KEY is set/marked
#   1  has/marked/get/emit: it is not; load: FILE unreadable
#   2  Invalid key or usage
function __fish_template_store --argument-names op --description 'fish-template value store'
    set -e argv[1]
    set -l keyre '^[a-z_][a-z0-9_]*$'
    switch "$op"
        case reset
            set -l vars (set -gn | string match -r '^__ft[vm]_.*')
            set -q vars[1]; and set -eg $vars
            return 0
        case set
            set -l mark 0
            if test "$argv[1]" = --mark
                set mark 1
                set -e argv[1]
            end
            string match -qr -- $keyre "$argv[1]"; or return 2
            set -g __ftv_$argv[1] $argv[2..]
            test $mark -eq 1; and set -g __ftm_$argv[1] 1
            return 0
        case get
            set -q __ftv_$argv[1]; or return 1
            set -l v __ftv_$argv[1]
            set -l vals $$v
            set -q vals[1]; and printf '%s\n' $vals
            return 0
        case has
            set -q __ftv_$argv[1]
            return $status
        case marked
            set -q __ftm_$argv[1]
            return $status
        case emit
            set -q __ftv_$argv[1]; or return 1
            set -l v __ftv_$argv[1]
            set -l vals $$v
            if set -q vals[1]
                echo "set -l $argv[1]" (string escape -- $vals)
            else
                echo "set -l $argv[1]"
            end
            return 0
        case load
            set -l mark
            set -l defaults 0
            while string match -q -- '--*' "$argv[1]"
                switch $argv[1]
                    case --mark
                        set mark --mark
                    case --defaults
                        set defaults 1
                    case '*'
                        return 2
                end
                set -e argv[1]
            end
            set -l file $argv[1]
            test -f "$file"; and test -r "$file"; or return 1
            set -l recipe 0
            __fish_template_is_generated $file; and set recipe 1
            set -l inside 0
            while read -l line
                if string match -qr -- '^\s*# ── fish-template recipe ──$' $line
                    set inside 1
                    continue
                end
                string match -qr -- '^\s*# ── end recipe ──$' $line; and break
                string match -qr -- '^#\s+─+ Fragment' $line; and break
                test $recipe -eq 1; and test $inside -eq 0; and continue
                string match -qr -- '^\s*set -l [a-z_][a-z0-9_]*(\s|$)' $line; or continue
                printf '%s\n' $line | read -lat toks
                test $defaults -eq 1; and set -q __ftv_$toks[3]; and continue
                __fish_template_store set $mark $toks[3..]
            end <$file
            return 0
        case '*'
            return 2
    end
end
