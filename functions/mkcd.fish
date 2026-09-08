# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# SYNOPSIS
#   mkcd [-s | --silent] <dir>
#
# DESCRIPTION
#   Creates a directory (including any missing parent directories) and
#   immediately changes into it. Prints a tree of created directories by
#   default, or suppresses output with -s. Delegates creation to
#   _fish_mkdir_p.
#
# ARGUMENTS
#   -h, --help    Show usage help
#   -s, --silent  Suppress directory creation output
#   <dir>         Directory to create and enter
#
# EXIT STATUS
#   0  Directory created (or already existed) and entered successfully
#   1  Directory creation or cd failed
#
# EXAMPLE
#   mkcd ~/projects/myapp
#   mkcd ~/projects/newapp/src
function mkcd --description 'Create a directory (with parents) and cd into it'
    __fish_palette

    if contains -- -h $argv; or contains -- --help $argv; or test (count $argv) -eq 0
        echo "$c_head""Usage:$c_reset $c_cmd""mkcd$c_reset $c_arg""<dir>$c_reset"
        echo
        echo "  Create $c_arg""<dir>$c_reset (including missing parents) and cd into it."
        echo
        echo "$c_head""Arguments:$c_reset"
        echo "  $c_arg""<dir>$c_reset   Directory to create and enter"
        echo
        echo "$c_head""Flags:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset   Show this help message"
        echo "  $c_flag-s$c_reset, $c_flag--silent$c_reset  Suppress directory creation output"
        echo
        echo "$c_head""Examples:$c_reset"
        echo "  $c_cmd""mkcd$c_reset $c_arg~/projects/myapp$c_reset"
        echo "  $c_cmd""mkcd$c_reset $c_arg~/projects/myapp$c_reset""$c_dim""; git init$c_reset"
        return 0
    end

    set -l silent 0
    set -l dir
    for _arg in $argv
        switch $_arg
            case -s --silent
                set silent 1
            case '*'
                set dir $_arg
        end
    end

    set -l is_new 0
    test -d $dir; or set is_new 1
    if test $silent -eq 1
        _fish_mkdir_p --silent $dir; or return $status
    else
        _fish_mkdir_p --tree $dir; or return $status
    end

    cd $dir
    or return $status

    if test $is_new -eq 1
        echo "$c_ok""✔$c_reset  Created and entered $c_arg$dir$c_reset"
    else
        echo "$c_warn""→$c_reset  $c_arg$dir$c_reset already exists — entered"
    end
end
