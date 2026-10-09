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
    copy docker du dusize fast-cli ffetch gitui gitup jr \
    joplin less ls mkdir mv ping rawfish rg rm search ssh top \
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

# Functions whose first argument is a subcommand. These follow the help
# convention in CONTRIBUTING.md (Help requests): a bare `help` in the
# subcommand slot, -h/--help anywhere before --, never a side effect. Add
# new subcommand-style functions here AND to __help_subcommands below;
# test_help_subcommand_list_is_complete fails if either is forgotten.
set -g __help_subcommand_fns \
    auto-pull fish-deps jobrunner kitty-logging session-env superpowers

# Each function's documented subcommands, one "fn sub sub ..." row each.
set -g __help_subcommands \
    'auto-pull list add remove status' \
    'fish-deps status install update sync' \
    'jobrunner run list attach kill logs' \
    'kitty-logging install uninstall status dismiss' \
    'session-env install preview uninstall status list' \
    'superpowers on off'

# A sandbox for running those functions for real. Every external binary
# they can reach is a recording stub, and HOME and XDG_CONFIG_HOME point
# inside it, so a side effect shows up in the recorder or as a changed file.
function _help_sandbox_new
    set -l tmp (mktemp -d)
    # __fish_config_dir is read-only, derived from XDG_CONFIG_HOME, so the
    # sandbox carries its own copy of the data the functions read.
    mkdir -p $tmp/bin $tmp/home $tmp/cfg/fish
    cp -r $repo_root/data $tmp/cfg/fish/
    touch $tmp/invoked.log
    for b in agy apt apt-get brew busctl cargo claude curl dnf docker fzf git \
        gpg kitty konsole lazydocker limine-enroll-config limine-mkinitcpio \
        loginctl lsof mpv nohup pacman paru pipx sbctl screen steam sudo \
        sudoedit systemd-inhibit tmux uv vlc wezterm wget xdg-open yay
        printf '#!/bin/sh\necho "$(basename "$0") $*" >> %s\n' $tmp/invoked.log >$tmp/bin/$b
        chmod +x $tmp/bin/$b
    end
    echo $tmp
end

function _help_sandbox_run --argument-names tmp
    env TERM=dumb PATH="$tmp/bin:$PATH" HOME=$tmp/home XDG_CONFIG_HOME=$tmp/cfg \
        fish --no-config -c \
        "set -g fish_function_path $repo_root/functions; $argv[2..]"
end

# Fingerprint of every file under the sandbox's HOME and config dirs.
function _help_sandbox_state --argument-names tmp
    find $tmp/home $tmp/cfg -type f -exec md5sum '{}' + 2>/dev/null | sort
end

# Run CMDLINE in the sandbox and expect exit CODE with NEEDLE in the output.
function _help_expect --argument-names tmp code needle cmdline
    set -l out (_help_sandbox_run $tmp $cmdline 2>&1 | string collect)
    set -l got $pipestatus[1]
    if test $got -ne $code
        echo "    $cmdline: exit $got, expected $code"
        return 1
    end
    if not string match -q -- "*$needle*" "$out"
        echo "    $cmdline: output lacks \"$needle\""
        return 1
    end
end

function test_help_subcommand_matches_help_flag
    set -l failed 0
    for fn in $__help_subcommand_fns
        set -l want (_help_probe /nonexistent $fn --help 2>&1 | string collect)
        set -l got (_help_probe /nonexistent $fn help 2>&1 | string collect)
        set -l code $pipestatus[1]
        if test $code -ne 0
            echo "    $fn help: exit $code"
            set failed 1
        else if test "$got" != "$want"
            echo "    $fn help: output differs from $fn --help"
            set failed 1
        end
    end
    test $failed -eq 0
end

function test_help_after_subcommand_runs_nothing
    # Rule 3: users append --help when unsure what a command does, so it
    # must print the help and do nothing, wherever it sits before --.
    set -l tmp (_help_sandbox_new)
    set -l log $tmp/invoked.log
    set -l failed 0
    for row in $__help_subcommands
        set -l words (string split ' ' -- $row)
        set -l fn $words[1]
        set -l want (_help_sandbox_run $tmp "$fn --help" 2>&1 | string collect)
        set -l clean (_help_sandbox_state $tmp | string collect)
        for sub in $words[2..]
            for form in "$fn $sub --help" "$fn $sub -h" "$fn $sub x --help" "$fn --help $sub"
                set -l got (_help_sandbox_run $tmp $form 2>&1 | string collect)
                set -l code $pipestatus[1]
                if test $code -ne 0
                    echo "    $form: exit $code, expected 0"
                    set failed 1
                else if test "$got" != "$want"
                    echo "    $form: output differs from $fn --help"
                    set failed 1
                end
                set -l ran (string trim -- (command cat $log))
                if test -n "$ran"
                    echo "    $form EXECUTED: $ran"
                    set failed 1
                    echo -n "" >$log
                end
                if test "$(_help_sandbox_state $tmp | string collect)" != "$clean"
                    echo "    $form changed files under HOME or XDG_CONFIG_HOME"
                    set failed 1
                end
            end
        end
    end
    rm -rf $tmp
    test $failed -eq 0
end

function test_help_words_after_subcommand_are_data
    # Rules 4 and 5: after the subcommand a bare help is data, and -- makes
    # even --help data.
    set -l tmp (_help_sandbox_new)
    set -l failed 0
    _help_expect $tmp 2 "unknown group 'help'" "session-env install help"; or set failed 1
    _help_expect $tmp 2 "unknown group '--help'" "session-env install -- --help"; or set failed 1
    _help_expect $tmp 1 "not a git repository: help" "auto-pull add help"; or set failed 1
    _help_expect $tmp 1 "not a git repository: --help" "auto-pull add -- --help"; or set failed 1
    _help_expect $tmp 0 "Started job" "jobrunner run -n job -- make --help"; or set failed 1
    if not string match -q '*tmux new-session -d -s job make --help*' -- (command cat $tmp/invoked.log)
        echo "    jobrunner run -n job -- make --help: make did not receive --help"
        set failed 1
    end
    # The subcommand slot itself: -- makes --help an unknown subcommand.
    for fn in $__help_subcommand_fns
        _help_expect $tmp 2 "Run $fn help for usage." "$fn -- --help"; or set failed 1
    end
    rm -rf $tmp
    test $failed -eq 0
end

function test_help_bare_invocation
    # Decision 8: with a read-only default subcommand, run it; otherwise
    # print the help on stdout and exit 0.
    set -l tmp (_help_sandbox_new)
    set -l failed 0
    for fn in kitty-logging session-env superpowers
        set -l want (_help_sandbox_run $tmp "$fn --help" 2>/dev/null | string collect)
        set -l got (_help_sandbox_run $tmp $fn 2>/dev/null | string collect)
        set -l code $pipestatus[1]
        if test $code -ne 0; or test "$got" != "$want"
            echo "    $fn (no args): exit $code, or help not on stdout"
            set failed 1
        end
    end
    _help_expect $tmp 0 "Auto-pull registry" auto-pull; or set failed 1
    _help_expect $tmp 0 "No background jobs running." jobrunner; or set failed 1
    rm -rf $tmp
    test $failed -eq 0
end

function test_help_spelling_is_exact
    # Rules 6 and 9: only exact spellings are help; anything else is a
    # usage error (exit 2) that names the right spelling.
    set -l tmp (_help_sandbox_new)
    set -l failed 0
    for fn in $__help_subcommand_fns
        for word in HELP -help bogus-subcommand
            _help_expect $tmp 2 "Run $fn help for usage." "$fn $word"; or set failed 1
        end
    end
    rm -rf $tmp
    test $failed -eq 0
end

function test_help_subcommand_list_is_complete
    # A function with a subcommand dispatch or a documented bare `help`
    # must be listed, or none of the checks above would cover it.
    set -l failed 0
    set -l listed (string replace -r ' .*' '' -- $__help_subcommands)
    if test "$listed" != "$__help_subcommand_fns"
        echo "    __help_subcommands and __help_subcommand_fns name different functions"
        set failed 1
    end
    for f in $repo_root/functions/*.fish
        set -l text (command cat $f | string collect)
        string match -q '*# CATEGORY*' -- $text; or continue
        set -l name (path change-extension '' (path basename $f))
        contains -- $name $__help_exempt; and continue
        if string match -qr '(?m)^\s*set -l (cmd|subcmd) "?\$argv\[1\]|(?m)^#\s+help, -h, --help' -- $text
            if not contains -- $name $__help_subcommand_fns
                echo "    $name looks subcommand-style but is not in \$__help_subcommand_fns"
                set failed 1
            end
        end
    end
    test $failed -eq 0
end

# Published functions for which an unknown option is not a usage error,
# so test_usage_errors_exit_2 skips them. Rationale per group below.
#
# EXEMPT-DATA -- their positionals are data, so --definitely-not-an-option
# is read as a file, command, name or search term (mkcd would make a
# directory by that name, bkg would run it as a command).
set -g __usage_exempt bkg branch dockup fc mkcd poke \
    rand_string replay spark split wake-lock y
# EXEMPT-PASS -- forward their arguments to one other tool, which owns the
# error (lt hands it to eza, md to marktext).
set -a __usage_exempt dops lD lsr lss lstree lt ltr lx md p qc spwin tab \
    zoxide

function test_usage_errors_exit_2
    # Rule 9: misuse exits 2, so scripts can tell it from a failure. An
    # unknown option must also never reach a function's real work, which
    # the recording stubs catch if a function starts ignoring it.
    set -l tmp (_help_sandbox_new)
    set -l failed 0
    set -l published
    for f in $repo_root/functions/*.fish
        string match -q '*# CATEGORY*' -- (command cat $f | string collect); or continue
        set -l name (path change-extension '' (path basename $f))
        string match -q '_*' -- $name; and continue
        set -a published $name
        contains -- $name $__help_exempt $__usage_exempt; and continue
        # CI=true lets fzf_configure_bindings parse its arguments outside
        # an interactive shell.
        _help_sandbox_run $tmp "set -gx CI true; cd $tmp/home; $name --definitely-not-an-option" >/dev/null 2>&1
        set -l code $status
        if test $code -ne 2
            echo "    $name --definitely-not-an-option: exit $code, expected 2"
            set failed 1
        end
        # Read-only lookups are fine: jobrunner asks tmux/screen whether
        # the word names a running job before calling it unknown.
        set -l ran (string trim -- (command cat $tmp/invoked.log) \
            | string match -rv '^(tmux list-sessions|screen -ls)\b')
        if test -n "$ran"
            echo "    $name --definitely-not-an-option EXECUTED: $ran"
            set failed 1
            echo -n "" >$tmp/invoked.log
        end
    end
    # Guard against a stale opt-out list, as for $__help_exempt.
    for e in $__usage_exempt
        if not contains -- $e $published
            echo "    \$__usage_exempt lists '$e', which is no longer published"
            set failed 1
        end
    end
    rm -rf $tmp
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
check "subcommand functions accept a bare help, same as --help" true (test_help_subcommand_matches_help_flag; and echo true; or echo false)
check "subcommand-style functions are all listed" true (test_help_subcommand_list_is_complete; and echo true; or echo false)

section "help: convention for subcommand-style functions"
check "SUB --help prints help and runs nothing" true (test_help_after_subcommand_runs_nothing; and echo true; or echo false)
check "help after the subcommand, and anything after --, is data" true (test_help_words_after_subcommand_are_data; and echo true; or echo false)
check "bare invocation runs a read-only default or prints help" true (test_help_bare_invocation; and echo true; or echo false)
check "only exact spellings are help; others exit 2 naming it" true (test_help_spelling_is_exact; and echo true; or echo false)

section "usage errors"
check "every function exits 2 on an unknown option, running nothing" true (test_usage_errors_exit_2; and echo true; or echo false)

report
