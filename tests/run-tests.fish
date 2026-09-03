#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# CI test runner for this fish configuration.
#   1. Syntax-lints every tracked .fish file (fish -n).
#   2. Copies the config-relevant files into a throwaway sandbox (never
#      the live checkout -- this repo doubles as a real ~/.config/fish,
#      so a symlinked sandbox would let universal-variable writes like
#      first-run's escape into the real, gitignored fish_variables file)
#      and loads it as an isolated interactive session.
#   3. Runs the functional checks in tests/functional.fish inside that
#      loaded session.
#   4. Runs tests/test-agents-vault.fish as its own process; that suite
#      builds its own throwaway repos and needs no loaded config.
#
# Usage: fish tests/run-tests.fish

set -l script_dir (realpath (dirname (status filename)))
set -l repo_root (realpath $script_dir/..)
set -l overall_failed 0

# ---- Phase 1: syntax lint ------------------------------------------------
echo "== Syntax lint =="
set -l lint_files $repo_root/config.fish
for dir in functions conf.d completions integrations
    set -a lint_files (find $repo_root/$dir -name '*.fish' | sort)
end

set -l lint_failed 0
for f in $lint_files
    set -l out (fish -n $f 2>&1)
    if test $status -ne 0
        echo "  FAIL  "(string replace $repo_root/ '' $f)
        printf '%s\n' $out
        set lint_failed (math $lint_failed + 1)
    end
end
set -l lint_total (count $lint_files)
echo (math $lint_total - $lint_failed)"/$lint_total files passed lint"
if test $lint_failed -ne 0
    set overall_failed 1
end

# ---- Phase 2: isolated load + functional checks --------------------------
echo ""
echo "== Sandboxed load + functional checks =="

set -l sandbox (mktemp -d)
set -l sandbox_cfg $sandbox/xdgcfg/fish
mkdir -p $sandbox_cfg
# path-setup only adds directories that already exist (fish_add_path is a
# no-op on missing paths), so give it $HOME/.local/bin to find.
mkdir -p $sandbox/home/.local/bin

cp $repo_root/config.fish $sandbox_cfg/
test -f $repo_root/fish_plugins
and cp $repo_root/fish_plugins $sandbox_cfg/
for d in functions conf.d completions integrations themes data
    test -d $repo_root/$d
    and cp -r $repo_root/$d $sandbox_cfg/
end

set -l err_file (mktemp)
env -i \
    HOME=$sandbox/home \
    XDG_CONFIG_HOME=$sandbox/xdgcfg \
    PATH="$PATH" \
    TERM=xterm \
    __fish_config_op_autoexec=off \
    fish -i -c "source $repo_root/tests/functional.fish; functional_test_main" \
    2>$err_file
set -l functional_status $status

set -l stderr_out (cat $err_file)
rm -rf $sandbox $err_file

if test -n "$stderr_out"
    # Diagnostic only, not a gate: on machines with vendor fish configs
    # (e.g. CachyOS's cachyos-fish-config, which this repo's config.fish
    # sources when present) unrelated vendor warnings can land here. Real
    # breakage in this repo's own code is caught by the assertions below.
    echo "  Session stderr output (informational):"
    printf '%s\n' $stderr_out
end

if test $functional_status -ne 0
    set overall_failed 1
end

# ---- Phase 3: hermetic vault helper tests --------------------------------
# Run as its own fish process rather than inside the sandboxed session:
# the suite builds its own throwaway git repos and binds the vault, claude
# and agy roots to them, so it needs no loaded config and must never see
# the real ~/.claude.
echo ""
echo "== Vault helper tests =="
fish $repo_root/tests/test-agents-vault.fish
if test $status -ne 0
    set overall_failed 1
end

exit $overall_failed
