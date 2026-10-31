# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# CLASSIFICATION
#   bypasses-shadow(bash)
#
# SYNOPSIS
#   bashrun [--] <code>
#
# DESCRIPTION
#   Runs a snippet of Bash code in a child bash attached to the terminal, so
#   output streams live and interactive programs work, then carries its
#   exported-variable changes and its final directory back into the current
#   Fish session. Unlike replay, nothing is buffered, but Bash aliases and
#   functions are not carried back.
#
#   Enter calls this automatically for a command line that Fish cannot
#   parse but Bash can (see __bashrun_execute), rewriting the line to
#   bashrun '<code>' first so the history entry shows what actually ran.
#
#   Bash's $? starts as the status of the Fish command run just before.
#
# ARGUMENTS
#   code  Bash code to run; several arguments are joined with spaces
#   -h, --help  Show usage help (only as the sole argument)
#
# EXIT STATUS
#   The exit status of the Bash code
#   2  No code given, an unknown option, or bash is not installed
#
# EXAMPLE
#   bashrun 'for f in *.log; do gzip "$f"; done'
#   bashrun 'export FOO=bar; cd /tmp'
function bashrun --description 'Run Bash code live and carry its env and cwd back into Fish'
    # Still the previous command's status here; Bash's $? starts from it.
    set -l last_status $status
    if __fish_help_requested $argv; and not set -q argv[2]
        __fish_palette
        echo "$c_head""Usage:$c_reset $c_cmd""bashrun$c_reset $c_arg""<code>$c_reset  Run Bash code, then import its exported variables and cwd"
        echo "$c_head""Options:$c_reset"
        echo "       $c_flag-h$c_reset or $c_flag--help$c_reset  Print this help message"
        return 0
    end
    if test "$argv[1]" = --
        set -e argv[1]
    else if string match -q -- '-*' $argv[1]
        echo "bashrun: unknown option '$argv[1]' (put code that starts with - after --)" >&2
        return 2
    end
    if not set -q argv[1]
        echo "bashrun: no code given" >&2
        return 2
    end
    if not type -q bash
        echo "bashrun: bash is not installed" >&2
        return 2
    end

    set -l state (command mktemp)
    # The EXIT trap records the final cwd and environment even when the code
    # itself calls exit; it keeps the code's exit status.
    __BASHRUN_STATE=$state command bash -c 'trap '\''__s=$?; { printf "%s\0" "$PWD"; env -0; } >"$__BASHRUN_STATE"; exit $__s'\'' EXIT
(exit '$last_status')
'"$argv"
    set -l rc $status

    set -l entries (string split0 <$state)
    command rm -f -- $state
    set -q entries[1]; or return $rc

    set -l seen
    for entry in $entries[2..-1]
        set -l kv (string split -m 1 -- = $entry)
        set -l name $kv[1]
        set -a seen $name
        contains -- $name SHLVL _ PWD OLDPWD __BASHRUN_STATE; and continue
        string match -qr -- '^[A-Za-z_][A-Za-z0-9_]*$' $name; or continue
        string match -q -- 'BASH_FUNC_*' $name; and continue

        if string match -q -- '*PATH' $name
            set -l value (string split -- : $kv[2])
            test "$(string join : -- $$name)" = "$kv[2]"; or set -gx $name $value
        else
            test "$$name" = "$kv[2]"; and set -q $name; or set -gx $name $kv[2]
        end
    end
    # A variable the code unset is absent from bash's environment.
    for name in (set --export --names)
        contains -- $name $seen SHLVL _ PWD OLDPWD; or set -e $name
    end

    test "$entries[1]" = "$PWD"; or builtin cd -- $entries[1]
    return $rc
end
