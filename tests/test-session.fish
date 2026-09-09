# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: in-session
#
# Functional checks for foundational config behavior. Sourced by
# tests/run-tests.fish into a fully-loaded, sandboxed interactive fish
# session -- see that file for the sandbox setup. Assertions here are the
# ones that genuinely need a loaded config; anything testable against a
# single function belongs in an isolated suite instead.

section "session: environment"

check "XDG vars are all set" true (test -n "$XDG_CONFIG_HOME" -a -n "$XDG_CACHE_HOME" -a -n "$XDG_DATA_HOME" -a -n "$XDG_STATE_HOME"; and echo true; or echo false)
check "PATH includes ~/.local/bin" true (contains -- "$HOME/.local/bin" $PATH; and echo true; or echo false)
check "CDPATH includes ~/projects" true (contains -- "$HOME/projects" $CDPATH; and echo true; or echo false)
check "vi key bindings active" fish_vi_key_bindings "$fish_key_bindings"
check "abbreviations loaded" true (abbr -q n; and echo true; or echo false)
check "privacy variables set" true (test "$DO_NOT_TRACK" = 1 -a "$DISABLE_TELEMETRY" = 1; and echo true; or echo false)

section "session: functions"

set -l missing
for f in cat logs config-help fish-deps check_fish_deps config-settings
    functions -q $f; or set -a missing $f
end
check "core functions defined" "" "$missing"

check "exit is rewired to smart_exit" true (functions -q exit; and functions exit | string match -q '*smart_exit*'; and echo true; or echo false)
check "fish_greeting defined" true (functions -q fish_greeting; and echo true; or echo false)

set -l missing_vault
for f in agents-vault _agents_vault_dir _agents_repo_slug \
    _agents_repo_ensure_symlink _agents_repo_sync _agents_repo_install_tools
    functions -q $f; or set -a missing_vault $f
end
check "agents-vault functions defined" "" "$missing_vault"

# One assertion, not two, so this file maps 1:1 onto the fifteen test_*
# predicates it replaces and the suite's 15/15 baseline is preserved.
check "claude and agy wrappers call agents-vault" true (functions -q claude; and functions claude | string match -q '*agents-vault*'; and functions -q agy; and functions agy | string match -q '*agents-vault*'; and echo true; or echo false)

section "session: guards in a loaded session"

set -l tags (__fish_config_op_registry_lookup config cdpath)
check "registry lookup finds config:cdpath" overrides/environment "$tags"

set -l ptags (__fish_config_op_registry_lookup config privacy)
check "registry lookup finds config:privacy" overrides/privacy "$ptags"

__fish_config_op_enabled __fish_config_test_never_registered somesite
check "unregistered component fails open" 0 $status

section "session: vault dir override"

set -l saved
set -q __fish_agent_vault_dir; and set saved $__fish_agent_vault_dir
set -g __fish_agent_vault_dir /tmp/vault-override-check
set -l got (_agents_vault_dir)
set -e __fish_agent_vault_dir
test (count $saved) -gt 0; and set -g __fish_agent_vault_dir $saved
check "vault dir honors the override" /tmp/vault-override-check "$got"

section "session: conf.d guards are lazy in non-interactive scripts"

# A non-interactive shell must not load interactive-only conf.d work. The
# child inherits XDG_CONFIG_HOME from this sandboxed session, so it loads
# the same config under test. Each exit code names one regression.
#
# Assertion 5 (tailscale) is vacuously true where tailscale is not
# installed: conf.d/tailscale.fish returned early on `type -q tailscale`
# before this change, and completions/tailscale.fish does the same, so the
# function is absent either way. The test still cannot fail wrongly there
# -- it just stops proving anything about that one file. A positive
# "completions still work" check would need the binary present and would
# make the suite machine-dependent, so it stays out.
fish -c '
    abbr -q n; and exit 1
    functions -q fish_user_key_bindings; and exit 2
    functions -q expand_bang_all; and exit 3
    functions -q __fish_config_logging_changed; and exit 4
    functions -q __tailscale_perform_completion; and exit 5
    exit 0'
check "conf.d guards stay out of non-interactive scripts" 0 $status

# Positive counterpart to the assertion above: the guard must not over-fire.
check "fish_user_key_bindings still defined in-session" true (functions -q fish_user_key_bindings; and echo true; or echo false)

section "session: shared output palette"

function test_palette_roles_defined
    functions -q __fish_palette
    or begin
        echo "    __fish_palette is not defined"
        return 1
    end
    # Called from inside a function, the palette must land in THIS scope.
    __fish_palette
    set -l missing
    for role in c_reset c_head c_cmd c_arg c_flag c_warn c_err c_ok \
        c_accent c_dim c_sel c_hi
        if not set -q $role; or test -z "$$role"
            set -a missing $role
        end
    end
    if test (count $missing) -gt 0
        echo "    palette roles empty or unset: $missing"
        return 1
    end
    # Nothing may leak to global scope.
    if set -q -g c_reset
        echo "    __fish_palette leaked c_reset into global scope"
        return 1
    end
    return 0
end
check "palette roles all defined, non-empty, and scoped to the caller" true (test_palette_roles_defined; and echo true; or echo false)

# Every user-facing function that renders a coloured --help must still emit
# escape sequences.
#
# This is deliberately a RUNTIME check, never a static grep for
# __fish_palette. Measured on a deliberately broken functions/logs.fish --
# the palette call de-duplicated per indentation depth instead of per
# contiguous run, so the --help block lost its declarations without gaining
# a call:
#
#     fish tests/palette-bytes.fish
#       FAIL  logs --help    stdout=DIFF stderr=ok
#       baseline 431 B -> broken 150 B (every escape stripped)
#
#     fish -n functions/logs.fish        -> exit 0   (lint PASSES)
#     grep -c '__fish_palette' logs.fish -> 1        (grep PASSES)
#
# Both cheap checks are green on a file whose help output has lost all of
# its colour. Only running the function and looking for an \e byte catches
# it.
#
# functions/fish_prompt.fish is excluded BY NAME. It interpolates $c_dim
# from its own Catppuccin hex palette -- those are colour arguments passed
# to set_color, not captured escapes -- so it legitimately never calls
# __fish_palette and would otherwise look unconverted forever.
#
# qc is absent from the list on purpose: its --help shells out to aichat,
# which is not installed in CI, so its colour path is unreachable here.
# tests/palette-bytes.fish stubs aichat and does cover it.
function test_functions_keep_their_palette
    set -l colored agents-init agents-vault auto-pull config-settings \
        config-update detach dng2avif dockup edit jobrunner kitty-logging \
        logs mkcd open-url p pkg play-media rand_string replay repo-open \
        scrub smart_exit spark y
    set -l uncolored
    for fn in $colored
        functions -q $fn; or continue
        if not $fn --help 2>&1 | string match -qr \e
            set -a uncolored $fn
        end
    end
    if test (count $uncolored) -gt 0
        echo "    --help lost its colour: $uncolored"
        return 1
    end
    return 0
end
check "colored --help output keeps its escape sequences" true (test_functions_keep_their_palette; and echo true; or echo false)

section "session: config-settings state dump"

# The curses TUI is a child process: it can neither read the session's global
# variables nor write them, so everything it knows arrives through
# __config_settings_state. These cases run here, in a real loaded session,
# because session scope is exactly what an isolated suite cannot produce.

# Every sub-category __config_settings_subcats knows must reach the dump --
# the TUI does not carry a second copy of the taxonomy, so a category missing
# here is a category the TUI silently cannot show.
function test_state_dump_carries_the_whole_taxonomy
    # US/RS have to come from printf: fish does not expand \x escapes inside
    # double quotes, so a literal "\x1f" in a pattern matches backslash-x-1-f.
    set -l US (printf '\x1f')
    set -l dump (__config_settings_state | string split (printf '\x1e'))
    set -l want 0
    for cvar in __fish_config_op_aliases __fish_config_op_autoexec \
        __fish_config_op_overrides __fish_config_op_integrations \
        __fish_config_op_logging __fish_config_op_greeting
        set -l n (count (__config_settings_subcats $cvar))
        set want (math $want + $n)
        set -l got (count (string match -- "sub$US$cvar$US*" $dump))
        if test $got -ne $n
            echo "    $cvar: expected $n sub records, got $got"
            return 1
        end
    end
    set -l subs (count (string match -- "sub$US*" $dump))
    if test $subs -ne $want
        echo "    expected $want sub records in total, got $subs"
        return 1
    end
    return 0
end
check "state dump carries every sub-category" true (test_state_dump_carries_the_whole_taxonomy; and echo true; or echo false)

# Toggles are dumped per scope; value rows are universal-only. A variable that
# is unset must not appear at all -- absence is how the TUI renders DEFAULT.
function test_state_dump_records_both_scopes
    set -l US (printf '\x1f')
    set -g __fish_config_op_overrides off
    set -g sponge_delay 7
    set -l dump (__config_settings_state | string split (printf '\x1e'))
    set -e __fish_config_op_overrides
    set -e sponge_delay

    set -l failed 0
    if test (count (string match -- "var$US""session$US""__fish_config_op_overrides$US""off" $dump)) -ne 1
        echo "    session toggle missing from the dump"
        set failed 1
    end
    if test (count (string match -- "var$US""universal$US""sponge_delay$US""7" $dump)) -ne 1
        echo "    value row missing from the dump"
        set failed 1
    end
    if test (count (string match -- "var$US*$US""__fish_config_op_greeting$US*" $dump)) -ne 0
        echo "    an unset toggle was emitted; absence is what renders DEFAULT"
        set failed 1
    end
    # The conf.d registry data table shares the op_ prefix and is not a setting.
    if test (count (string match -- "var$US*$US""__fish_config_op_registry_*" $dump)) -ne 0
        echo "    the registry data table leaked into the dump"
        set failed 1
    end
    test $failed -eq 0
end
check "state dump records both scopes and omits unset variables" true (test_state_dump_records_both_scopes; and echo true; or echo false)

# The other half of the seam: what the TUI emits has to be runnable fish that
# actually moves the variable. Emitting is Python's job, applying is fish's.
function test_emitted_script_applies
    set -l tui $repo_root/scripts/config-settings-tui.py
    type -q python3; or return 1
    set -l script (python3 $tui --self-test >/dev/null 2>&1; and python3 -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cst", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
st = m.State("")
st.set("session", "__fish_config_op_greeting", "off")
st.set("universal", "sponge_delay", "11")
sys.stdout.write(m.emit(st, m.rows_by_var()))
' $tui)
    or return 1

    set -l tmp (command mktemp)
    printf '%s\n' $script >$tmp
    source $tmp
    command rm -f $tmp

    set -l failed 0
    test "$__fish_config_op_greeting" = off
    or begin
        echo "    sourcing the emitted script did not set the session toggle"
        set failed 1
    end
    test "$sponge_delay" = 11
    or begin
        echo "    sourcing the emitted script did not set the value row"
        set failed 1
    end
    set -e __fish_config_op_greeting
    set -Ue sponge_delay 2>/dev/null
    test $failed -eq 0
end
check "an emitted script applies when sourced" true (test_emitted_script_applies; and echo true; or echo false)
