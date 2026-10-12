#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# The variable plumbing behind config-settings (#238): __config_settings_apply
# (toggle rows), __config_settings_set_value (value pages),
# __config_settings_get_val and __config_settings_get_raw (what the panels
# display). These are what turn a keypress into a persistent `set -U`, so
# the scope they write to is the thing to pin down.
#
# Universal scope cannot be tested in this process: under `fish --no-config`
# (how run-tests.fish runs isolated suites) fish does not load or save
# universal variables at all, and `set -U` quietly creates a global. So the
# universal-scope cases run in a child fish started WITH config loading but
# with HOME, XDG_CONFIG_HOME and XDG_DATA_HOME all pointed into a mktemp
# sandbox: its fish_variables is a throwaway file, never the user's real one,
# and its config.fish is empty. Session-scope cases run here directly.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -g work (mktemp -d)

# Run fish code in a child whose universal variables live in a fresh
# sandbox. Each call gets its own sandbox unless $argv[2] names one, so a
# write and a later read can share state across two processes.
function uvar_run --argument-names code sandbox
    test -n "$sandbox"; or set sandbox (mktemp -d $work/uv.XXXXXX)
    env -i PATH=(string join : -- $PATH) HOME=$sandbox/home \
        XDG_CONFIG_HOME=$sandbox/cfg XDG_DATA_HOME=$sandbox/data TERM=dumb \
        (status fish-path) -c "set -p fish_function_path $repo_root/functions; $code" 2>/dev/null
end

set -g v __fish_test_cs238

# Both document "0 Always": erasing an unset variable, or a stale non-zero
# $status from the caller, must not leak through (#314).
section "exit status"

set -e $v
false
__config_settings_apply $v universal DEFAULT
check "apply: erasing an unset universal exits 0" 0 $status
false
__config_settings_apply $v session DEFAULT
check "apply: erasing an unset global exits 0" 0 $status
false
__config_settings_apply $v bogus on
check "apply: an unknown scope exits 0" 0 $status
check "set_value: erasing an unset universal exits 0" 0 \
    (uvar_run "false; __config_settings_set_value $v int ''; echo \$status")

# =============================================================================
# 1. __config_settings_apply -- universal scope
# =============================================================================
section "__config_settings_apply: universal"

check "on sets a universal 'on'" universal:on \
    (uvar_run "__config_settings_apply $v universal on; set -qU $v; and echo universal:\$$v")
check "off sets a universal 'off'" universal:off \
    (uvar_run "__config_settings_apply $v universal off; set -qU $v; and echo universal:\$$v")
check "an arbitrary value is stored verbatim" "universal:a b" \
    (uvar_run "__config_settings_apply $v universal 'a b'; set -qU $v; and echo universal:\$$v")
check "on does not touch the session scope" no-global \
    (uvar_run "__config_settings_apply $v universal on; set -qg $v; and echo global; or echo no-global")
check "DEFAULT erases the universal" erased \
    (uvar_run "set -U $v on; __config_settings_apply $v universal DEFAULT; not set -qU $v; and echo erased")

# Persistence: the write must reach fish_variables, which is the whole point
# of universal scope. Read it back from a second, independent process.
set -l sb (mktemp -d $work/persist.XXXXXX)
uvar_run "__config_settings_apply $v universal off" $sb
check "a universal write persists to a new shell" off (uvar_run "echo \$$v" $sb)
check "it lands in the sandbox's fish_variables" true \
    (string match -q "*$v*off*" -- (command cat $sb/cfg/fish/fish_variables 2>/dev/null); and echo true; or echo false)
uvar_run "__config_settings_apply $v universal DEFAULT" $sb
check "a universal erase persists too" unset (uvar_run "set -q $v; and echo set; or echo unset" $sb)

# =============================================================================
# 2. __config_settings_apply -- session scope (this process)
# =============================================================================
section "__config_settings_apply: session"

set -e $v
__config_settings_apply $v session on
check "session on sets a global 'on'" on (set -qg $v; and echo $$v)
__config_settings_apply $v session off
check "session off sets a global 'off'" off (set -qg $v; and echo $$v)
__config_settings_apply $v session DEFAULT
check "session DEFAULT erases the global" unset (set -q $v; and echo set; or echo unset)

set -g $v on
__config_settings_apply $v session arbitrary
check "session ignores values other than on/off/DEFAULT" on $$v
set -e $v
__config_settings_apply $v bogus on
check "an unknown scope sets nothing" unset (set -q $v; and echo set; or echo unset)

# =============================================================================
# 3. __config_settings_get_val
# =============================================================================
section __config_settings_get_val

set -e $v
check "unset in session reads DEFAULT" DEFAULT (__config_settings_get_val $v session)
set -g $v on
check "session reads the global value" on (__config_settings_get_val $v session)
set -g $v off
check "session reads off" off (__config_settings_get_val $v session)
set -g $v 'x y'
check "a value with a space is read whole" "x y" (__config_settings_get_val $v session)
set -g $v first second
check "a list reads its first element" first (__config_settings_get_val $v session)
set -g $v ''
check "an empty value reads DEFAULT" DEFAULT (__config_settings_get_val $v session)
set -e $v
check "always returns 0" 0 (__config_settings_get_val $v session >/dev/null; echo $status)

check "universal reads the universal value" off \
    (uvar_run "set -U $v off; __config_settings_get_val $v universal")
check "universal is DEFAULT when only a global exists" DEFAULT \
    (uvar_run "set -g $v on; __config_settings_get_val $v universal")
check "session is DEFAULT when only a universal exists" DEFAULT \
    (uvar_run "set -U $v on; __config_settings_get_val $v session")
check "each scope reads its own value when both are set" "on off" \
    (uvar_run "set -U $v off; set -g $v on; echo (__config_settings_get_val $v session) (__config_settings_get_val $v universal)")
check "apply then get_val round-trips (universal)" off \
    (uvar_run "__config_settings_apply $v universal off; __config_settings_get_val $v universal")

# =============================================================================
# 4. __config_settings_get_raw
# =============================================================================
section __config_settings_get_raw

set -e $v
check "unset reads DEFAULT" DEFAULT (__config_settings_get_raw $v)
set -g $v 5
check "a scalar is printed as-is" 5 (__config_settings_get_raw $v)
set -g $v 0 1 130
check "a list is space-joined on one line" "0 1 130" (__config_settings_get_raw $v)
check "a list is a single output line" 1 (count (__config_settings_get_raw $v))
set -g $v -n
check "a dash-leading value is printed, not parsed as a flag" -n (__config_settings_get_raw $v)
set -e $v
check "a universal is seen too" 7 (uvar_run "set -U $v 7; __config_settings_get_raw $v")

# =============================================================================
# 5. __config_settings_set_value (universal, in the child)
# =============================================================================
section __config_settings_set_value

check "a scalar is stored as one universal value" "universal:1:5" \
    (uvar_run "__config_settings_set_value $v int 5; set -qU $v; and echo universal:(count \$$v):\$$v")
check "a non-list value with spaces stays one element" "1:a b" \
    (uvar_run "__config_settings_set_value $v str 'a b'; echo (count \$$v):\$$v")
check "a dash-leading value is stored, not taken as a flag" -e \
    (uvar_run "__config_settings_set_value $v str -e; printf '%s\\n' \$$v")
for input in "0 1 130" "0,1,130" "0, 1, 130" "  0  1,,130 "
    check "list '$input' splits to three elements" "3:0|1|130" \
        (uvar_run "__config_settings_set_value $v list '$input'; echo (count \$$v):(string join '|' \$$v)")
end
check "an empty value erases the universal" unset \
    (uvar_run "set -U $v 5; __config_settings_set_value $v int ''; set -qU $v; and echo set; or echo unset")

# Glob characters and substitutions in typed input are data, not code.
check "typed input is not expanded" '$(echo pwned)*' \
    (uvar_run "__config_settings_set_value $v str '\$(echo pwned)*'; echo \$$v")

# The scrollback mirror: the exported SCROLLBACK_HISTORY_* follow the value.
check "history dir mirrors into SCROLLBACK_HISTORY_DIR" /tmp/logs:exported \
    (uvar_run "__config_settings_set_value __fish_scrollback_history_dir path /tmp/logs; echo \$SCROLLBACK_HISTORY_DIR:(set -qx SCROLLBACK_HISTORY_DIR; and echo exported)")
check "resetting history dir falls back to ~/.terminal_history" ok \
    (uvar_run "set -U __fish_scrollback_history_dir /x; __config_settings_set_value __fish_scrollback_history_dir path ''; test \"\$SCROLLBACK_HISTORY_DIR\" = \"\$HOME/.terminal_history\"; and echo ok")
check "max files mirrors into SCROLLBACK_HISTORY_MAX_FILES" 42 \
    (uvar_run "__config_settings_set_value __fish_scrollback_history_max_files int 42; echo \$SCROLLBACK_HISTORY_MAX_FILES")
check "resetting max files falls back to 100" 100 \
    (uvar_run "set -U __fish_scrollback_history_max_files 7; __config_settings_set_value __fish_scrollback_history_max_files int ''; echo \$SCROLLBACK_HISTORY_MAX_FILES")
check "other variables do not touch the mirror" unset \
    (uvar_run "__config_settings_set_value $v int 3; set -q SCROLLBACK_HISTORY_DIR; and echo set; or echo unset")

set -e $v
command rm -rf $work
report
