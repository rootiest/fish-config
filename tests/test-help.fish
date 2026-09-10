#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for the header-driven --help renderer (__fish_help_header) and
# the repo-wide rule that every user-facing function handles -h/--help.
#
# Runs isolated (no `# MODE:` marker): every case spawns its own --no-config
# fish with an explicit fish_function_path, so none of it needs a loaded
# session -- only $repo_root/functions (or a throwaway fixture dir) on the
# child's function path.

source (realpath (dirname (status filename)))/lib.fish

# Helper: run `<fn> $argv` in a throwaway fish that can see both $dir and
# this repo's real functions/, so a fixture function can call the real
# __fish_help_header. $dir is always mktemp -d output, never spaced.
function _help_probe --argument-names dir
    env TERM=dumb fish --no-config -c \
        "set -g fish_function_path $dir $repo_root/functions; $argv[2..]"
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
        end >$tmp/fixturefn.fish

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
        end >$tmp/headerless.fish
    # A comment run carrying no `# LABEL` line at all.
    printf '%s\n' \
        '# just an ordinary comment, no labels here' \
        'function malformed' \
        '    __fish_help_header (status current-function) $argv; and return 0' \
        "    touch $tmp/BODY-RAN" \
        end >$tmp/malformed.fish

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
            "set -g fish_function_path $repo_root/functions; $fn --help" 2>/dev/null)
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

# Functions published in the manual that are exempt from the -h/--help
# rule. Rationale per entry is in the EXEMPT-* comments below. This array
# is the ONLY machine-readable copy of the exempt set.
#
# EXEMPT-A -- shadows a same-named binary, or forwards $argv to one named
# tool that owns its own --help. Intercepting would hide that tool's help,
# and for the C1-guarded shadows it also breaks the disabled-fallback
# contract, where the bare tool is supposed to answer.
set -g __help_exempt \
    agy antigravity-ide bash cat cdi cffetch cheat claude clone clonet \
    config-toggle copy docker du dusize fast-cli ffetch gitui gitup jr \
    joplin less ls mkdir mv paste ping rawfish rg rm search ssh top \
    view yt-dlp
# EXEMPT-B -- invoked by fish, never typed by a user.
set -a __help_exempt fish_prompt fish_right_prompt fish_mode_prompt \
    sponge_filter_secrets

function test_every_user_facing_function_has_help
    set -l failed 0
    set -l published

    for f in $repo_root/functions/*.fish
        set -l lines (string split \n -- (command cat $f))
        # Published == carries a `# CATEGORY` block, matching
        # manualtools.parse_functions.
        contains -- "# CATEGORY" (string trim -- $lines); or continue
        # Resolve the real defined name; the file stem can disagree with it
        # (formerly dops.fish defined `docker`, fixed by splitting it into
        # dops.fish and docker.fish).
        set -l name (string match -rg '^\s*function\s+(\S+)' -- $lines)[1]
        test -n "$name"; or continue
        set name (string trim -c "'\"" -- $name)
        string match -q '_*' -- $name; and continue
        set -a published $name

        contains -- $name $__help_exempt; and continue

        # Body == everything from the `function` line down, comment lines
        # dropped, so a header that merely mentions --help cannot pass.
        set -l body
        set -l in_body 0
        for l in $lines
            test $in_body -eq 1; or string match -qr '^\s*function\s' -- $l; and set in_body 1
            test $in_body -eq 1; or continue
            string match -qr '^\s*#' -- $l; and continue
            set -a body $l
        end
        if not string match -qr -- '__fish_help_header|_flag_help|h/help|--help' \
                (string join \n -- $body)
            echo "    $name: no -h/--help handling and not in \$__help_exempt"
            set failed 1
        end
    end

    # Guard against a stale exempt list: every exempt name must still be a
    # published function. Catches renames and deletions.
    for e in $__help_exempt
        if not contains -- $e $published
            echo "    \$__help_exempt lists '$e', which is no longer published"
            set failed 1
        end
    end

    test $failed -eq 0
end

section "help: renderer"
check "full render: headings, indentation, multi-paragraph description" true (test_help_renderer; and echo true; or echo false)

section "help: renderer degrades safely"
check "headerless/malformed functions still print and exit 0" true (test_help_renderer_degrades_safely; and echo true; or echo false)

section "help: destructive paths"
check "eight functions never execute their destructive path on --help" true (test_help_never_executes_destructive_path; and echo true; or echo false)

section "help: coverage"
check "every user-facing function has --help or is exempt" true (test_every_user_facing_function_has_help; and echo true; or echo false)

report
