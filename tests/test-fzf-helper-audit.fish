#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Regression coverage for #255, the audit of the remaining _fzf_* helpers
# after #218:
#   - _fzf_search_git_status: a selected path is inserted into the command
#     line escaped for fish. git status --short leaves names such as
#     a'b;touch X;$(touch X) verbatim (and only C-quotes names with ", \ or
#     control characters), so inserting them raw would run the payload when
#     the user pressed Enter.
#   - _fzf_search_variables: the path of the `set --show` dump is spliced into
#     the --preview command string and must stay one inert argument.
#
# Runs isolated (no `# MODE:` marker): its own `fish --no-config` process,
# and every case works inside a mktemp -d sandbox.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -l start $PWD
set -l sandbox (path resolve (mktemp -d))
cd $sandbox

# Headless stubs for the interactive pieces. `commandline` records what the
# function would insert; `_fzf_wrapper` selects every line it is fed (git
# status) or records its arguments and selects nothing (variables).
function commandline
    if contains -- --replace $argv
        set -g __stub_replaced $argv[4..-1]
    else if contains -- --current-token $argv
        # An empty token, as one empty line: a bare empty substitution would
        # leave the callee's `string replace` with no input and reading stdin.
        echo ''
    end
end

# ---- _fzf_search_git_status ------------------------------------------------
section "_fzf_search_git_status: inserted paths are escaped"

function git
    if test "$argv[1]" = rev-parse
        return 0
    end
    printf '%s\n' $__stub_status
end
function _fzf_wrapper
    cat
end

# Feed one `git status --short` line, then replay the inserted text in a fresh
# shell (inside the sandbox) and print the arguments it yields, one per line.
function __replay_status --argument-names line
    set -g __stub_status $line
    set -g __stub_replaced
    _fzf_search_git_status >/dev/null 2>&1
    fish --no-config -c "printf '%s\n' $__stub_replaced" 2>&1
end

set -l evil "a'b;touch PWNED_gs1;\$(touch PWNED_gs1)"
check "unquoted hostile name round-trips as one inert argument" "$evil" (__replay_status "?? $evil")
check "no injected command ran (unquoted)" false (test -e PWNED_gs1; and echo true; or echo false)

set -l evil_q 'a"b;touch PWNED_gs2'
check "C-quoted name (embedded \") round-trips" "$evil_q" (__replay_status '?? "a\\"b;touch PWNED_gs2"')
check "no injected command ran (C-quoted)" false (test -e PWNED_gs2; and echo true; or echo false)

check "C-quoted name with a space round-trips" "two words.txt" (__replay_status 'A  "two words.txt"')

set -l evil_rn "new'; touch PWNED_gs3; 'x"
check "rename target is escaped" "$evil_rn" (__replay_status "R  old.txt -> $evil_rn")
check "no injected command ran (rename)" false (test -e PWNED_gs3; and echo true; or echo false)

check "plain path is unchanged" "src/foo.fish" (__replay_status ' M src/foo.fish')

functions -e git _fzf_wrapper __replay_status

# ---- _fzf_search_variables -------------------------------------------------
section "_fzf_search_variables: dump path in --preview stays one argument"

function _fzf_wrapper
    set -g __stub_fzf_args $argv
    return 1
end

printf '%s\n' foo bar >names.txt
set -l evil_path "$sandbox/x;touch PWNED_var1;\$(touch PWNED_var1) y"
_fzf_search_variables $evil_path names.txt >/dev/null 2>&1

set -l idx (contains -i -- --preview $__stub_fzf_args)
set -l next (math $idx + 1)
# Replay fzf's substitution ({} -> 'foo') in a fresh shell with a stub
# _fzf_extract_var_info that reports how many arguments it was handed.
set -l preview (string replace -- '{}' "'foo'" $__stub_fzf_args[$next])
set -l got (fish --no-config -c "function _fzf_extract_var_info; count \$argv; printf '%s\n' \$argv; end; $preview" 2>&1)
check "preview receives exactly two arguments" 2 "$got[1]"
check "variable name is the first argument" foo "$got[2]"
check "hostile dump path is the second argument, intact" "$evil_path" "$got[3]"
check "no injected command ran (variables)" false (test -e PWNED_var1; and echo true; or echo false)

functions -e commandline _fzf_wrapper
cd $start
rm -rf $sandbox
report
