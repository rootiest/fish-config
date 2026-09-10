#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# CI test runner for this fish configuration.
#   1. Syntax-lints and indent-checks every tracked .fish file (fish -n, fish_indent --check).
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
set -l lint_files $repo_root/config.fish
for dir in functions conf.d completions integrations tests
    set -a lint_files (find $repo_root/$dir -name '*.fish' | sort)
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
# the running shell. Measured: $__fish_config_op_registry_keys has 65 entries
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
    env XDG_CONFIG_HOME=$xdg/cfg XDG_DATA_HOME=$xdg/data \
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
    # very config it tests, which shadows these: `cp` is an alias for `cp -i`,
    # `rm` is a trash wrapper, `cat` resolves to bat. Only `cp` is an actual
    # hazard today -- `-i` on a non-empty destination reads EOF in a
    # non-interactive runner and SILENTLY SKIPS the copy while exiting 0,
    # which would leave the sandbox missing config files and report success.
    # `rm -rf` and `cat` were measured and behave correctly as-is (the rm
    # wrapper bails to `command rm` on any non-recursive flag, so -rf really
    # deletes and does not trash). Prefixed anyway: a test runner must not
    # depend on the configuration under test.
    command cp $repo_root/config.fish $sandbox_cfg/
    test -f $repo_root/fish_plugins
    and command cp $repo_root/fish_plugins $sandbox_cfg/
    for d in functions conf.d completions integrations themes data
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
