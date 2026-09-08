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

# ── Header-driven --help ─────────────────────────────────────────────
# Helper: run `<fn> $argv` in a throwaway fish that can see both $dir and
# the loaded session's function path, so a fixture function can call the
# real __fish_help_header. Paths here are mktemp -d output, never spaced.
function _help_probe --argument-names dir
    env TERM=dumb fish --no-config -c \
        "set -g fish_function_path $dir $fish_function_path; $argv[2..]"
end

function test_help_renderer
    set -l tmp (mktemp -d)
    printf '%s\n' \
        '# Copyright (C) 2026 Rootiest' \
        '' \
        '# CATEGORY' \
        '#   99-fixture' \
        '#' \
        '# SYNOPSIS' \
        '#   fixturefn [options]' \
        '#' \
        '# DESCRIPTION' \
        '#   First paragraph.' \
        '#' \
        '#   Second paragraph.' \
        '#' \
        '# ARGUMENTS' \
        '#   -x        Do the thing' \
        '#       more  Indented continuation' \
        '#' \
        '# EXAMPLE' \
        '#   fixturefn -x' \
        'function fixturefn' \
        '    __fish_help_header (status current-function) $argv; and return 0' \
        '    echo RAN-BODY' \
        'end' >$tmp/fixturefn.fish

    set -l out (_help_probe $tmp 'fixturefn --help')
    set -l code $status
    set -l text (string join \n $out)
    rm -rf $tmp

    set -l failed 0
    if test $code -ne 0
        echo "    renderer exited $code, expected 0"
        set failed 1
    end
    if contains -- RAN-BODY $out
        echo "    body executed despite --help"
        set failed 1
    end
    if not contains -- USAGE $out
        echo "    missing USAGE heading (SYNOPSIS should render as USAGE)"
        set failed 1
    end
    if contains -- CATEGORY $out
        echo "    CATEGORY leaked into the menu"
        set failed 1
    end
    if not string match -q '*      more  Indented continuation*' -- $text
        echo "    nested ARGUMENTS indentation lost"
        set failed 1
    end
    # Index-based, not a glob: fish's `string match` glob `*` does not
    # span newlines, so a pattern straddling two lines silently never
    # matches and the assertion would pass for the wrong reason.
    set -l i (contains -i -- "  First paragraph." $out)
    if test -z "$i"
        echo "    DESCRIPTION body missing entirely"
        set failed 1
    else
        # Indices hoisted: a command substitution inside a quoted index
        # ("$out[(math ...)]") is a fish parse error, not an expansion.
        set -l gap (math $i + 1)
        set -l nxt (math $i + 2)
        if test -n "$out[$gap]"
            echo "    multi-paragraph DESCRIPTION lost its blank line"
            set failed 1
        else if test "$out[$nxt]" != "  Second paragraph."
            echo "    second paragraph missing after the blank"
            set failed 1
        end
    end
    test $failed -eq 0
end

function test_help_renderer_degrades_safely
    # The renderer must return 1 ONLY when argv[1] is not a help flag.
    # A missing or label-less header must still print and exit 0, because
    # returning 1 hands control back to the caller's body -- and the body
    # of upgrade(1) is `paru -Syu --noconfirm`.
    set -l tmp (mktemp -d)
    printf '%s\n' \
        'function headerless' \
        '    __fish_help_header (status current-function) $argv; and return 0' \
        "    touch $tmp/BODY-RAN" \
        'end' >$tmp/headerless.fish
    # A comment run carrying no `# LABEL` line at all.
    printf '%s\n' \
        '# just an ordinary comment, no labels here' \
        'function malformed' \
        '    __fish_help_header (status current-function) $argv; and return 0' \
        "    touch $tmp/BODY-RAN" \
        'end' >$tmp/malformed.fish

    set -l failed 0
    for fn in headerless malformed
        set -l out (_help_probe $tmp "$fn --help")
        set -l code $status
        if test $code -ne 0
            echo "    $fn --help exited $code, expected 0"
            set failed 1
        end
        if test (count $out) -eq 0
            echo "    $fn --help printed nothing"
            set failed 1
        end
        if not contains -- $fn $out
            echo "    $fn --help did not name the function"
            set failed 1
        end
        if test -e $tmp/BODY-RAN
            echo "    $fn executed its body despite --help"
            set failed 1
            rm -f $tmp/BODY-RAN
        end
    end

    # The inverse: no help flag must return 1 and let the body run.
    _help_probe $tmp headerless >/dev/null 2>&1
    if not test -e $tmp/BODY-RAN
        echo "    body did NOT run when no help flag was passed"
        set failed 1
    end

    rm -rf $tmp
    # Explicit, never a trailing `if`: standing gotcha #5 -- an if with no
    # branch taken resolves $status to 0 and the test would pass silently.
    test $failed -eq 0
end

function test_help_never_executes_destructive_path
    # These eight ignore $argv entirely, so before the header-driven help
    # landed, `upgrade --help` ran `paru -Syu --noconfirm`. The check has
    # to prove --help does NOT reach the destructive path *without* ever
    # running it: every external binary the eight can reach is shadowed by
    # a recording stub on PATH, and the recorder must stay empty.
    #
    # WARNING: a silent pass here means a MISSING STUB, not success. If a
    # function shows neither an EXECUTED line nor its own help, its
    # command is absent from the stub list below -- add it. A test that
    # cannot fail proves nothing about a body that runs sudo pacman -Rns.
    set -l root (realpath (dirname (status filename))/..)
    set -l tmp (mktemp -d)
    mkdir -p $tmp/bin
    set -l log $tmp/invoked.log
    touch $log

    for b in sudo pacman paru yay loginctl busctl tmux systemd-inhibit \
        sudoedit limine-enroll-config limine-mkinitcpio sbctl git fzf steam
        printf '#!/bin/sh\necho "$(basename "$0") $*" >> %s\n' $log >$tmp/bin/$b
        chmod +x $tmp/bin/$b
    end

    set -l failed 0
    for fn in cleanup fzf-update limine-edit lock screensleep sudo-toggle \
        tmux-clean upgrade
        set -l out (env TERM=dumb PATH="$tmp/bin:$PATH" HOME=$tmp \
            fish --no-config -c \
            "set -g fish_function_path $root/functions $fish_function_path
             $fn --help" 2>/dev/null)
        set -l code $status

        if test $code -ne 0
            echo "    $fn --help exited $code, expected 0"
            set failed 1
        end
        if not contains -- $fn $out
            echo "    $fn --help did not print its own help"
            set failed 1
        end
        set -l ran (string trim -- (command cat $log))
        if test -n "$ran"
            echo "    $fn --help EXECUTED: $ran"
            set failed 1
        end
        echo -n "" >$log
    end

    rm -rf $tmp
    test $failed -eq 0
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
