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

function test_op_enabled_fail_open
    # An identity/site pair with no registry entry must resolve to
    # enabled -- the documented fail-open default.
    __fish_config_op_enabled __fish_config_test_never_registered somesite
end

function test_greeting_function_defined
    functions -q fish_greeting
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
