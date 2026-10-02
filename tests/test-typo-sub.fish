# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: in-session
#
# ^old^new history substitution: the typo_sub abbreviation
# (conf.d/abbr.fish) and expand_typo_sub (conf.d/bash_expands.fish). Both
# exist only in a loaded interactive config, hence in-session. History
# lives in the sandbox HOME, so appending to it here is safe.

section "typo_sub: abbreviation wiring"

set -l def (abbr --show | string match -r -- '.* -- typo_sub$')
check "typo_sub abbreviation registered" true (test -n "$def"; and echo true; or echo false)
check "typo_sub expands via expand_typo_sub" true (string match -q -- '*--function expand_typo_sub*' "$def"; and echo true; or echo false)
check "typo_sub expands anywhere on the line" true (string match -q -- '*--position anywhere*' "$def"; and echo true; or echo false)

section "typo_sub: expand_typo_sub"

builtin history append 'echo foo foo'
check "^foo^bar replaces every occurrence" "echo bar bar" (expand_typo_sub '^foo^bar')
check "^foo^ deletes the match" "echo  " (expand_typo_sub '^foo^')
check "^nomatch^x leaves the last command unchanged" "echo foo foo" (expand_typo_sub '^nomatch^x')

builtin history append 'git commit -m "feat"'
check "substitutes within quoted arguments" 'git commit -m "fix"' (expand_typo_sub '^feat^fix')

builtin history append 'grep -n x file'
check "replacement may start with a dash" "grep -v x file" (expand_typo_sub '^-n^-v')

check "non-matching token is returned as-is" plain (expand_typo_sub plain)

set -l saved_overrides
set -q __fish_config_op_overrides; and set saved_overrides $__fish_config_op_overrides
set -g __fish_config_op_overrides 0
set -l out (expand_typo_sub '^grep^rg')
check "C3 overrides off: expansion refused" 1 $status
check "C3 overrides off: nothing printed" "" "$out"
set -e -g __fish_config_op_overrides
set -q saved_overrides[1]; and set -g __fish_config_op_overrides $saved_overrides
