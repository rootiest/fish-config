# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# DEPENDENCIES
#   fzf
#
# CLASSIFICATION
#   manual-section(12-function-templates)
#
# SYNOPSIS
#   fish-template [list|info|new|edit|regen|show|ls|help] [ARGS...]
#
# DESCRIPTION
#   Builds your own fish functions from templates, without writing code.
#   Pick a target (what runs: one command, the first installed of several,
#   a sequence of steps, or a set of subcommands), stack any modifiers on
#   it (how it runs: extra arguments, environment changes, a confirmation
#   question, a working directory, retries, a time limit, a log file, a
#   desktop notification), and answer a few questions. fish-template
#   writes a documented function with its own --help to the user-dots
#   functions/ directory, where it autoloads in every shell. Functions can
#   call each other, so a sequence can chain functions you made earlier.
#
#   Each generated function keeps its answers (its recipe) as settings at
#   the top of its body. edit asks the questions again with those answers
#   as defaults; regen rebuilds after fish-template improves; show prints
#   the recipe so you can copy it to another machine.
#
# ARGUMENTS
#   list                 List the templates and presets
#   info NAME            Show a template's settings and defaults, or a preset
#   new [NAME]           Create a function (asks for anything not given)
#   edit NAME            Change a function made by fish-template
#   regen NAME...|--all  Rebuild functions from their recipes
#   show NAME            Print a function's recipe, ready for --from
#   ls                   List the functions you made
#   help, -h, --help     Show this help
#
#   Options for new and edit:
#   -t, --target T       Target: command, fallback, sequence or dispatcher
#   -w, --with M[,M]     Modifiers to stack (repeatable)
#   -s, --set KEY=VAL    Give a setting. List settings take space-separated
#                        words; line settings take one entry per --set
#   -f, --from FILE      Read settings from a recipe file (never executed)
#   -p, --preset P       Start from a preset (see list)
#   -o, --output DIR     Write to DIR instead of the user-dots functions/
#   -n, --dry-run        Print the function instead of writing it
#   -y, --yes            Ask nothing; unset settings take their defaults
#       --force          Replace an existing file
#
# EXIT STATUS
#   0  Success, or help was shown
#   1  Refused (file exists or was not made by fish-template), cancelled,
#      or failed
#   2  Usage error: unknown subcommand, template or setting, or a bad value
#
# EXAMPLE
#   fish-template new
#   fish-template new claude --preset allow-telemetry --yes
#   fish-template new rg --target command --set command_cmd=rg --with args --set args_prepend=--smart-case --yes
#   fish-template edit deploy
#
# NOTES
#   Templates live in templates/ (targets/, modifiers/, presets/). Output
#   goes to $__fish_user_dots_path/functions/, which conf.d puts first on
#   $fish_function_path, so your function overrides one of the same name
#   from this config. fish-template warns when a name shadows a builtin,
#   a function or a command, and never replaces a file it did not make.
#
#   Full guide, with every template's settings: help config templates
function fish-template --description 'Build your own functions from templates, without writing code'
    if test "$argv[1]" = help; or not set -q argv[1]; or __fish_help_requested $argv
        __fish_help_header (status current-function) --help
        return 0
    end
    __fish_palette
    set -l usage "Run $c_cmd""fish-template help$c_reset for usage."
    set -l outdir (__fish_user_dots_dir)/functions
    set -l sub $argv[1]
    set -e argv[1]
    switch $sub
        case list
            for kind in target modifier preset
                switch $kind
                    case target
                        echo "$c_head""Targets$c_reset (what runs):"
                    case modifier
                        echo "$c_head""Modifiers$c_reset (how it runs; stack any number):"
                    case preset
                        echo "$c_head""Presets$c_reset (ready-made; use with new --preset):"
                end
                for n in (__fish_template_names $kind)
                    set -l f (__fish_template_file $n)
                    test $kind = preset; and set f (__fish_template_file --preset $n)
                    printf '  %s%-12s%s %s\n' "$c_cmd" $n "$c_reset" "$(__fish_template_meta $f SUMMARY)"
                end
            end
            return 0
        case info
            if not set -q argv[1]
                echo "$c_err""fish-template: info needs a template or preset name$c_reset" >&2
                echo $usage >&2
                return 2
            end
            set -l f (__fish_template_file $argv[1])
            if test -n "$f"
                echo "$c_cmd$argv[1]$c_reset: "(__fish_template_meta $f SUMMARY)
                echo "Kind: "(__fish_template_meta $f KIND)
                set -l applies (__fish_template_meta $f APPLIES); and echo "Works with: $applies"
                echo Settings:
                __fish_template_store reset
                __fish_template_store load --defaults $f
                for row in (__fish_template_settings $f)
                    set -l c (string split \t -- $row)
                    set -l v __ftv_$c[1]
                    set -l req ''
                    test $c[3] = 1; and set req ', required'
                    printf '  %s%s%s (%s%s)\n      %s\n      default: %s\n' "$c_arg" $c[1] "$c_reset" $c[2] $req "$c[4]" "$(string join ' ' -- (string escape -- $$v))"
                end
                __fish_template_store reset
                return 0
            end
            set -l p (__fish_template_file --preset $argv[1])
            if test -n "$p"
                echo "$c_cmd$argv[1]$c_reset (preset): "(__fish_template_meta $p SUMMARY)
                string match -r -- '^set -l .*' <$p
                return 0
            end
            echo "$c_err""fish-template: no template or preset named '$argv[1]'$c_reset" >&2
            echo $usage >&2
            return 2
        case new
            __fish_template_new $argv
            return $status
        case edit
            __fish_template_new --edit $argv
            return $status
        case regen
            __fish_template_regen $argv
            return $status
        case show ls
            argparse 'o/output=' -- $argv; or return 2
            set -q _flag_output; and set outdir $_flag_output
            if test $sub = ls
                __fish_template_generated $outdir
                return 0
            end
            if not set -q argv[1]
                echo "$c_err""fish-template: show needs a function name$c_reset" >&2
                echo $usage >&2
                return 2
            end
            set -l f (__fish_template_locate $argv[1] $outdir); or return 1
            echo "# fish-template recipe for $argv[1]. Use: fish-template new NAME --from FILE"
            set -l inside 0
            while read -l line
                if string match -qr -- '^\s*# ── fish-template recipe ──$' $line
                    set inside 1
                else if string match -qr -- '^\s*# ── end recipe ──$' $line
                    break
                else if test $inside -eq 1
                    string trim -- $line
                end
            end <$f
            return 0
        case '*'
            echo "$c_err""fish-template: unknown subcommand '$sub'$c_reset" >&2
            echo $usage >&2
            return 2
    end
end
