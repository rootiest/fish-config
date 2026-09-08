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

section "session: config-settings diff redraw"

# Locks in the invariant the diff-redraw renderer depends on: each draw
# function's real line count must match the height config-settings.fish's
# dispatch derives from it (count $new_frame) -- see
# __cs_dispatch_draw in functions/config-settings.fish.
function test_draw_line_count_matches_panel_h
    set -l toggle_vars \
        __fish_config_op_aliases __fish_config_op_autoexec \
        __fish_config_op_overrides __fish_config_op_integrations \
        __fish_config_op_logging __fish_config_op_greeting \
        __fish_config_opinionated

    set -l lines (__config_settings_draw 0 universal $toggle_vars)
    if test (count $lines) -ne 16
        echo "    __config_settings_draw: expected 16 lines, got "(count $lines)
        return 1
    end

    set -l vlines (__config_settings_draw_value 0 sponge)
    if test (count $vlines) -ne 16
        echo "    __config_settings_draw_value: expected 16 lines, got "(count $vlines)
        return 1
    end

    set -l n (count (__config_settings_subcats __fish_config_op_aliases))
    set -l slines (__config_settings_draw_subcat 0 universal __fish_config_op_aliases)
    set -l want (math 7 + $n)
    if test (count $slines) -ne $want
        echo "    __config_settings_draw_subcat: expected $want lines, got "(count $slines)
        return 1
    end
    return 0
end
check "draw functions' line counts match their panel heights" true (test_draw_line_count_matches_panel_h; and echo true; or echo false)

function test_diff_redraw_unchanged_lines_are_bare_newlines
    functions -q __config_settings_diff_redraw; or return 1
    set -l old (string join \n -- AAA BBB CCC | string collect)
    set -l new (string join \n -- AAA BBB CCC | string collect)
    set -l out (__config_settings_diff_redraw "$old" "$new" | string collect -N)
    test "$out" = \n\n\n
end
check "diff_redraw: unchanged lines are bare newlines" true (test_diff_redraw_unchanged_lines_are_bare_newlines; and echo true; or echo false)

function test_diff_redraw_changed_line_is_cleared_and_rewritten
    functions -q __config_settings_diff_redraw; or return 1
    set -l old (string join \n -- AAA BBB CCC | string collect)
    set -l new (string join \n -- AAA XYZ CCC | string collect)
    set -l out (__config_settings_diff_redraw "$old" "$new" | string collect -N)
    test "$out" = \n\e\[2K\rXYZ\n\n
end
check "diff_redraw: a changed line is cleared and rewritten" true (test_diff_redraw_changed_line_is_cleared_and_rewritten; and echo true; or echo false)
