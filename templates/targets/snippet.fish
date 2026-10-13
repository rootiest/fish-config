# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  snippet
# KIND      target
# SUMMARY   Fill your arguments into slots {1}, {2}, {@} of a long command line
# PHRASE    Runs {snippet_cmd}
# SYNOPSIS  {name} ARGS...
# STATUS    Exit status of the command; 2 if an argument is missing or extra
# EXAMPLE   {name} https://example.com/video

#   ─────────────────────────────── Settings ───────────────────────────────

# Command to run, one program and its arguments; write {1}, {2}... for your arguments and {@} for the rest. (list, required)
set -l snippet_cmd

#   ─────────────────────────── Fragment: guard ────────────────────────────

# Slots are filled in as list elements, never parsed again: an argument
# with spaces, quotes or $(...) stays one literal word. The highest {N}
# is how many arguments are required; without {@}, more is an error.
set -l __ft_need 0
set -l __ft_rest 0
for __ft_word in $snippet_cmd
    test "$__ft_word" = '{@}'; and set __ft_rest 1
    for __ft_n in (string match -ar --groups-only -- '\{([1-9][0-9]*)\}' $__ft_word)
        test $__ft_n -gt $__ft_need; and set __ft_need $__ft_n
    end
end
set -l __ft_argc (count $argv)
if test $__ft_argc -lt $__ft_need; or begin
        test $__ft_rest -eq 0; and test $__ft_argc -gt $__ft_need
    end
    set -l __ft_usage (status current-function)
    for __ft_n in (seq $__ft_need)
        set -a __ft_usage ARG$__ft_n
    end
    test $__ft_rest -eq 1; and set -a __ft_usage '[ARGS...]'
    if test $__ft_argc -lt $__ft_need
        echo (status current-function)": expected $__ft_need argument(s), got $__ft_argc" >&2
    else
        echo (status current-function)": too many arguments (expected $__ft_need)" >&2
    end
    echo "Usage: $__ft_usage" >&2
    return 2
end
set -l __ft_from (math $__ft_need + 1)
for __ft_word in $snippet_cmd
    if test "$__ft_word" = '{@}'
        set -a cmd $argv[$__ft_from..]
        continue
    end
    # Scan left to right, so text that came from an argument is never
    # searched for slots again.
    set -l __ft_out ''
    while set -l __ft_m (string match -r --groups-only -- '^(.*?)\{([1-9][0-9]*)\}(.*)$' $__ft_word)
        set __ft_out "$__ft_out$__ft_m[1]$argv[$__ft_m[2]]"
        set __ft_word $__ft_m[3]
    end
    set -a cmd "$__ft_out$__ft_word"
end
# A snippet named after its program must call the binary, not itself.
if test "$cmd[1]" = (status current-function)
    set -l __ft_bin (command -s $cmd[1]); or begin
        echo (status current-function)": $cmd[1]: command not found" >&2
        return 127
    end
    set cmd[1] $__ft_bin
end

#   ──────────────────────────── Fragment: run ─────────────────────────────

$cmd
set __ft_status $status
