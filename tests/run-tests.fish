#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# CI test runner for this fish configuration.
#   1. Syntax-lints and indent-checks every .fish file git does not ignore (fish -n, fish_indent --check).
#   2. Discovers tests/test-*.fish and reads the mode each suite declares
#      in its own header (`# MODE: isolated` or `# MODE: in-session`).
#   3. Runs each isolated suite as its own --no-config fish process with
#      throwaway XDG dirs.
#   4. Sources every in-session suite into ONE sandboxed interactive fish
#      session built from a copy of this config (never the live checkout
#      -- this repo doubles as a real ~/.config/fish, so a symlinked
#      sandbox would let universal-variable writes like first-run's escape
#      into the real, gitignored fish_variables file).
#   5. Sums the per-suite assertion counts and reports a total.
#
# Assertions come from tests/lib.fish (section/check/report); suites are
# never special-cased here by name.
#
# Usage: fish tests/run-tests.fish

set -l script_dir (realpath (dirname (status filename)))
set -l repo_root (realpath $script_dir/..)
set -l overall_failed 0

# ---- Phase 1: syntax & indent lint ---------------------------------------
echo "== Syntax & indent lint =="
# Skip git-ignored files: on a live install Fisher writes its plugin files
# into functions/, conf.d/ and completions/, and their style is not ours to
# lint (#321). New files not yet added are still linted. Outside git, fall
# back to every file on disk.
set -l lint_dirs functions conf.d completions templates tests
set -l lint_files (git -C $repo_root ls-files --cached --others --exclude-standard \
    config.fish $lint_dirs/'*.fish' 2>/dev/null)
if test $status -eq 0; and set -q lint_files[1]
    # path filter drops index entries deleted from the working tree.
    set lint_files (path filter -f $repo_root/$lint_files)
else
    set lint_files $repo_root/config.fish
    for dir in $lint_dirs
        set -a lint_files (find $repo_root/$dir -name '*.fish' | sort)
    end
end

set -l syntax_failed 0
set -l indent_failed 0
for f in $lint_files
    set -l out (fish -n $f 2>&1)
    if test $status -ne 0
        echo "  FAIL (syntax) "(string replace $repo_root/ '' $f)
        printf '%s\n' $out
        set syntax_failed (math $syntax_failed + 1)
    end

    if not fish_indent --check $f >/dev/null 2>&1
        echo "  FAIL (indent) "(string replace $repo_root/ '' $f)
        set indent_failed (math $indent_failed + 1)
    end
end
set -l lint_total (count $lint_files)
echo (math $lint_total - $syntax_failed)"/$lint_total files passed syntax check"
echo (math $lint_total - $indent_failed)"/$lint_total files passed indent check"
if test $syntax_failed -ne 0 -o $indent_failed -ne 0
    set overall_failed 1
end

# ---- Phase 1b: shadow-classification lint --------------------------------
# Catches a bare C1-shadowed-command call in a function body with no
# matching uses-shadow(name) or self-limiting(name) in that function's own
# CLASSIFICATION header -- the exact bug class fixed across fc.fish,
# dng2avif.fish, _scrollback_prune_junk.fish, mkcd.fish, and mkrep.fish. A
# bare call is either declared (uses-shadow: wanted; self-limiting: safe
# because the shadow's own logic neutralizes it, e.g. rm/mkdir's flag check
# or grep/cat's tty-auto-detected color) or it's undocumented at best, a bug
# at worst -- the lint never guesses which on its own; see
# docs/function-classification-schema.md for the full tag definitions and
# why the reasoning belongs in a tag, not in this script.
#
# Scoped to functions/*.fish only: the one-function-per-file convention
# there makes "everything after the function line is its body" exact, with
# no block-depth parser needed. conf.d/*.fish can define several functions
# in one file and isn't covered -- see docs/function-classification-schema.md.
echo
echo "== Shadow-classification lint =="

# help and edit are deliberately excluded: help's real bypass is
# __original_help (not command/builtin), and edit has no backing binary at
# all to bypass to -- see docs/manual/08-components-reference/01-c1-command-shadows.md.
set -l shadow_names ls cat cd rm less du top ping ssh rg mkdir bash cp mv wget grep fgrep egrep dir vdir claude

set -l class_checked 0
set -l class_files_failed 0
set -l class_issues 0

for f in $repo_root/functions/*.fish
    set -l lines (cat $f)

    # Find the function line; everything before it is header, everything
    # from it onward is body (one function per file).
    set -l func_idx 0
    for i in (seq (count $lines))
        if string match -qr '^function ' -- $lines[$i]
            set func_idx $i
            break
        end
    end
    test $func_idx -eq 0; and continue
    set class_checked (math $class_checked + 1)

    # Pull uses-shadow(...) and self-limiting(...) names from the
    # CLASSIFICATION tag line, if any -- either one accounts for a bare call.
    set -l declared
    for i in (seq (math $func_idx - 1))
        if test "$lines[$i]" = "# CLASSIFICATION"; and test $i -lt $func_idx
            set -l tagline $lines[(math $i + 1)]
            for tag in uses-shadow self-limiting
                set -l m (string match -r "$tag"'\(([^)]*)\)' -- $tagline)
                test -n "$m[2]"; and set -a declared (string trim -- (string split ',' -- $m[2]))
            end
            break
        end
    end

    set -l file_failed 0
    for i in (seq $func_idx (count $lines))
        set -l line $lines[$i]
        # Strip quoted spans and comments so string literals (error
        # messages, --description text) never masquerade as a call.
        set -l stripped (string replace -ra '"[^"]*"' '' -- $line)
        set stripped (string replace -ra "'[^']*'" '' -- $stripped)
        set stripped (string replace -r '#.*$' '' -- $stripped)

        for name in $shadow_names
            if string match -qr '(^|[;|(]|\band\b|\bor\b|\bnot\b|\bif\b|\bwhile\b|\bbegin\b)\s*'"$name"'(\s|$)' -- $stripped
                if not contains -- $name $declared
                    echo "  FAIL (shadow) "(string replace $repo_root/ '' $f)": line $i calls bare '$name' with no uses-shadow($name)/self-limiting($name)"
                    set class_issues (math $class_issues + 1)
                    set file_failed 1
                end
            end
        end
    end
    test $file_failed -eq 1; and set class_files_failed (math $class_files_failed + 1)
end
echo (math $class_checked - $class_files_failed)"/$class_checked functions passed shadow-classification check"
if test $class_issues -ne 0
    set overall_failed 1
end

# ---- Phase 1c: test-reference lint ---------------------------------------
# Every functions/<name>.fish must be named by at least one suite
# (tests/test-*.fish, tests/test_*.py) or carry a reviewed entry with a
# reason in tests/coverage-allowlist.txt. Stale entries fail too: an
# allow-listed function that a suite now references, or that no longer
# exists, must come off the list, so the gap can only shrink (issue #238).
#
# "Referenced" means the name appears as a whole token, split on anything
# outside [A-Za-z0-9_-] (the characters fish function names here use). A
# plain substring match is not enough: it counted `ld` as covered by
# `build` and `hist` by `history`. This driver and lib.fish are not suites,
# so the shadow-name list above does not count as testing `less` or `ping`.
echo
echo "== Test-reference lint =="

set -l ref_tokens (command grep -ohE '[A-Za-z0-9_-]+' \
        (find $script_dir -maxdepth 1 \( -name 'test-*.fish' -o -name 'test_*.py' \)) | sort -u)

set -l allow_file $script_dir/coverage-allowlist.txt
set -l allow_names
set -l ref_issues 0
if test -f $allow_file
    for line in (string match -rv '^\s*(#|$)' <$allow_file)
        set -l parts (string split -m1 ' -- ' -- $line)
        set -l name (string trim -- $parts[1])
        if test (count $parts) -lt 2; or test -z (string trim -- $parts[2])
            echo "  FAIL (allowlist) $name: entry has no reason (expected 'name -- reason')"
            set ref_issues (math $ref_issues + 1)
        end
        set -a allow_names $name
        if not test -f $repo_root/functions/$name.fish
            echo "  FAIL (allowlist) $name: no functions/$name.fish; remove the stale entry"
            set ref_issues (math $ref_issues + 1)
        else if contains -- $name $ref_tokens
            echo "  FAIL (allowlist) $name: now referenced by a suite; remove the stale entry"
            set ref_issues (math $ref_issues + 1)
        end
    end
end

# Tracked files only: Fisher installs plugin functions (sponge, fisher
# itself) into functions/ on the user's machine, git-ignored. They are
# upstream code, absent from a CI checkout, and must not change the result.
set -l tracked_functions (git -C $repo_root ls-files 'functions/*.fish')
or set tracked_functions (string replace $repo_root/ '' $repo_root/functions/*.fish)

set -l ref_checked 0
set -l ref_missing 0
for f in $tracked_functions
    set -l name (path change-extension '' (path basename $f))
    set ref_checked (math $ref_checked + 1)
    contains -- $name $ref_tokens; and continue
    contains -- $name $allow_names; and continue
    echo "  FAIL (untested) functions/$name.fish: no suite references it and it is not in tests/coverage-allowlist.txt"
    set ref_missing (math $ref_missing + 1)
end
echo (math $ref_checked - $ref_missing)"/$ref_checked functions referenced by a suite or allow-listed"
if test $ref_missing -ne 0 -o $ref_issues -ne 0
    set overall_failed 1
end

# ---- Phase 2: discover suites --------------------------------------------
# Mode is declared by the suite, not by this driver. Detection is
# case-insensitive so a near-miss like "# Mode: in-session" is caught rather
# than silently read as "no marker"; the comparison is exact so only the two
# real spellings are accepted. Absence means isolated, the safe default -- a
# suite that forgets the marker gets its own clean process instead of being
# injected into a loaded session, and no typo can ever promote a suite into
# in-session. Duplicate markers resolve first-match-wins.
set -l isolated_suites
set -l session_suites
for f in (find $script_dir -name 'test-*.fish' | sort)
    set -l decl (grep -im1 '^# *mode:' $f)
    if test -z "$decl"
        set -a isolated_suites $f
    else if test "$decl" = "# MODE: in-session"
        set -a session_suites $f
    else if test "$decl" = "# MODE: isolated"
        set -a isolated_suites $f
    else
        echo "  FAIL  "(basename $f)": unrecognized mode declaration: $decl" >&2
        set overall_failed 1
    end
end

set -l counts (mktemp)

# ---- Phase 3: isolated suites --------------------------------------------
# HOME is deliberately NOT overridden here. Read this before "improving" it.
#
# Overriding XDG_CONFIG_HOME/XDG_DATA_HOME plus --no-config is what makes these
# runs isolated: the universal-variable file fish can reach is a fresh empty
# one, and no config.fish/conf.d is loaded. Without that, an "isolated" suite
# runs against the user's LIVE config and real universal variables -- this repo
# doubles as a real ~/.config/fish -- so a guard test doing
# `set -e __fish_config_op_logging` would erase a real universal variable out of
# the running shell. Measured: $__fish_config_op_registry_keys has 66 entries
# under a plain `fish`, 0 under `fish --no-config`.
#
# `env -i HOME=$sandbox` was tried and REJECTED. It looks strictly more
# hermetic, but test-agents-vault.fish's hermeticity floor snapshots the real
# $HOME/.claude/memory and $HOME/.gemini/antigravity-cli and asserts them
# unchanged at the end. Point HOME at a sandbox and both snapshots read "absent"
# before and after: the assertions still pass while asserting nothing. A change
# that turns a real assertion into a tautology without turning anything red is
# the worst failure mode a test harness has. Keeping HOME real is what keeps
# those two assertions biting.
#
# Overriding XDG_DATA_HOME is a hermeticity gain on top of the isolation:
# _agents_vault_dir falls back to
# ${XDG_DATA_HOME:-$HOME/.local/share}/agent-vault, so a vault path that no test
# overrode lands in a temp dir instead of the user's real ~/.local/share.
for suite in $isolated_suites
    echo ""
    echo "== "(string replace $repo_root/ '' $suite)" =="
    set -l xdg (mktemp -d)
    env -u NO_COLOR XDG_CONFIG_HOME=$xdg/cfg XDG_DATA_HOME=$xdg/data \
        FISH_CONFIG_TEST_ROOT=$repo_root FISH_CONFIG_TEST_COUNTS=$counts \
        fish --no-config $suite
    if test $status -ne 0
        set overall_failed 1
    end
    command rm -rf $xdg
end

# ---- Phase 4: in-session suites ------------------------------------------
# All in-session suites share ONE sandboxed interactive session: building it
# (copying the config, starting fish -i) is the expensive part.
#
# The config is COPIED, never symlinked. This repo doubles as a real
# ~/.config/fish, so a symlinked sandbox would let universal-variable writes
# like first-run's escape into the real, gitignored fish_variables file.
if test (count $session_suites) -gt 0
    echo ""
    echo "== Sandboxed load + session checks =="

    set -l sandbox (mktemp -d)
    set -l sandbox_cfg $sandbox/xdgcfg/fish
    mkdir -p $sandbox_cfg
    # path-setup only adds directories that already exist (fish_add_path is a
    # no-op on missing paths), so give it $HOME/.local/bin to find.
    mkdir -p $sandbox/home/.local/bin

    # Every utility below goes through `command`. This driver runs under the
    # very config it tests, which shadows these: `cp` is a wrapper that passes
    # `-i`, `rm` is a trash wrapper, `cat` resolves to bat. Only `cp` is an actual
    # hazard today -- `-i` on a non-empty destination reads EOF in a
    # non-interactive runner and SILENTLY SKIPS the copy while exiting 0,
    # which would leave the sandbox missing config files and report success.
    # `rm -rf` and `cat` were measured and behave correctly as-is (the rm
    # wrapper bails to `command rm` on any non-recursive flag, so -rf really
    # deletes and does not trash). Prefixed anyway: a test runner must not
    # depend on the configuration under test.
    command cp $repo_root/config.fish $sandbox_cfg/
    # The sandbox has no sponge, so drop it from the copied plugin list: with
    # it listed, conf.d/sponge_privacy.fish prints its "history secret
    # filtering is inactive" notice into the stderr block below. The notice
    # itself is asserted in test-first-run.fish.
    test -f $repo_root/fish_plugins
    and string match -v -- '*meaningful-ooo/sponge*' <$repo_root/fish_plugins >$sandbox_cfg/fish_plugins
    for d in functions conf.d completions themes data
        test -d $repo_root/$d
        and command cp -r $repo_root/$d $sandbox_cfg/
    end

    set -l srcs
    for s in $session_suites
        set -a srcs "source $s;"
    end

    set -l err_file (mktemp)
    env -i \
        HOME=$sandbox/home \
        XDG_CONFIG_HOME=$sandbox/xdgcfg \
        PATH="$PATH" \
        TERM=xterm \
        __fish_config_op_autoexec=off \
        FISH_CONFIG_TEST_ROOT=$repo_root \
        FISH_CONFIG_TEST_COUNTS=$counts \
        fish -i -c "source $repo_root/tests/lib.fish; $srcs report" 2>$err_file
    set -l session_status $status

    set -l stderr_out (command cat $err_file)
    command rm -rf $sandbox $err_file

    if test -n "$stderr_out"
        # Diagnostic only, not a gate: on machines with vendor fish configs
        # (e.g. CachyOS's cachyos-fish-config, which this repo's config.fish
        # sources when present) unrelated vendor warnings can land here. Real
        # breakage in this repo's own code is caught by the assertions.
        echo "  Session stderr output (informational):"
        printf '%s\n' $stderr_out
    end

    if test $session_status -ne 0
        set overall_failed 1
    end
end

# ---- Phase 5: totals -----------------------------------------------------
set -l total_run 0
set -l total_failed 0
for line in (command cat $counts)
    set -l parts (string split ' ' -- $line)
    set total_run (math $total_run + $parts[1])
    set total_failed (math $total_failed + $parts[2])
end
command rm -f $counts

echo ""
echo "TOTAL: "(math $total_run - $total_failed)"/$total_run assertions passed"
if test $total_failed -ne 0
    set overall_failed 1
end

exit $overall_failed
