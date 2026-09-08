# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Functional checks for foundational config behavior. Sourced inside a
# fully-loaded, sandboxed interactive fish session by tests/run-tests.fish
# -- see that file for the sandbox setup. Each test_* function returns 0
# on pass, non-zero on fail; functional_test_main collects and runs them.

function test_xdg_defaults
    test -n "$XDG_CONFIG_HOME" -a -n "$XDG_CACHE_HOME" \
        -a -n "$XDG_DATA_HOME" -a -n "$XDG_STATE_HOME"
end

function test_path_additions
    contains -- "$HOME/.local/bin" $PATH
end

function test_cdpath
    contains -- "$HOME/projects" $CDPATH
end

function test_vi_key_bindings
    test "$fish_key_bindings" = fish_vi_key_bindings
end

function test_abbreviations_loaded
    abbr -q n
end

function test_core_functions_defined
    for f in cat logs config-help fish-deps check_fish_deps config-settings
        if not functions -q $f
            echo "    missing function: $f"
            return 1
        end
    end
end

function test_exit_rewired
    functions -q exit
    and functions exit | string match -q '*smart_exit*'
end

function test_op_registry_lookup
    functions -q __fish_config_op_registry_lookup
    or return 1
    set -l tags (__fish_config_op_registry_lookup config cdpath)
    test $status -eq 0 -a (count $tags) -gt 0
end

function test_privacy_variables
    test "$DO_NOT_TRACK" = "1" -a "$DISABLE_TELEMETRY" = "1"
end

function test_privacy_op_registry_lookup
    functions -q __fish_config_op_registry_lookup
    or return 1
    set -l tags (__fish_config_op_registry_lookup config privacy)
    test $status -eq 0 -a "$tags" = "overrides/privacy"
end

function test_op_enabled_fail_open
    # An identity/site pair with no registry entry must resolve to
    # enabled -- the documented fail-open default.
    __fish_config_op_enabled __fish_config_test_never_registered somesite
end

function test_greeting_function_defined
    functions -q fish_greeting
end

function test_agents_vault_defined
    for f in agents-vault _agents_vault_dir _agents_repo_slug \
        _agents_repo_ensure_symlink _agents_repo_sync \
        _agents_repo_install_tools
        if not functions -q $f
            echo "    missing function: $f"
            return 1
        end
    end
end

function test_wrappers_call_agents_vault
    functions -q claude; or return 1
    functions claude | string match -q '*agents-vault*'; or return 1
    functions -q agy; or return 1
    functions agy | string match -q '*agents-vault*'
end

function test_vault_dir_honors_override
    set -l saved
    set -q __fish_agent_vault_dir; and set saved $__fish_agent_vault_dir
    set -g __fish_agent_vault_dir /tmp/vault-override-check
    set -l got (_agents_vault_dir)
    set -e __fish_agent_vault_dir
    test (count $saved) -gt 0; and set -g __fish_agent_vault_dir $saved
    test "$got" = /tmp/vault-override-check
end

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
# it. The full test suite was also green throughout.
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

function functional_test_main
    set -l names (functions -a | string match 'test_*' | sort)
    set -l failed 0
    for name in $names
        if $name
            echo "  PASS  $name"
        else
            echo "  FAIL  $name"
            set failed (math $failed + 1)
        end
    end
    echo ""
    echo (math (count $names) - $failed)"/"(count $names)" passed"
    return $failed
end
