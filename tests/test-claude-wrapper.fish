#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for the claude wrapper's privacy handling: DO_NOT_TRACK and
# DISABLE_TELEMETRY are stripped from the claude process itself, while
# scripts/claude-shell-prefix puts them back for the commands it runs.
#
# Runs isolated (no `# MODE:` marker): guard variables are set as globals in
# a --no-config process with temp XDG dirs, so nothing real is touched.
# C1 is disabled throughout so agents-init and agents-vault never run.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish
set -g __fish_config_op_aliases 0

set -l helper $repo_root/scripts/claude-shell-prefix

# A stub claude binary that reports the environment it was started with.
set -l tmp (mktemp -d)
printf '%s\n' '#!/bin/sh' \
    'echo "DNT=[$DO_NOT_TRACK] DT=[$DISABLE_TELEMETRY] PREFIX=[$CLAUDE_CODE_SHELL_PREFIX] args=$*"' >$tmp/claude
chmod +x $tmp/claude
set -gx PATH $tmp $PATH
set -gx DO_NOT_TRACK 1
set -gx DISABLE_TELEMETRY 1

section "claude wrapper: privacy enabled"
set -e CLAUDE_CODE_SHELL_PREFIX
# __fish_config_dir is read-only (the temp XDG dir here), so the wrapper's
# path is checked against it; the helper itself is exercised from the fork.
check "vars stripped from claude, prefix points at helper" \
    "DNT=[] DT=[] PREFIX=[$__fish_config_dir/scripts/claude-shell-prefix] args=a b c" (claude a 'b c')
check "the wrapper's own shell keeps the vars" "1 1" "$DO_NOT_TRACK $DISABLE_TELEMETRY"

set -gx CLAUDE_CODE_SHELL_PREFIX /usr/local/bin/my-prefix
check "an existing prefix is left alone" \
    "DNT=[] DT=[] PREFIX=[/usr/local/bin/my-prefix] args=" (claude)
set -e CLAUDE_CODE_SHELL_PREFIX

section "claude wrapper: privacy disabled"
set -g __fish_config_op_overrides 0
check "vars pass through, no prefix set" "DNT=[1] DT=[1] PREFIX=[] args=" (claude)
set -e __fish_config_op_overrides

section "claude-shell-prefix helper"
set -l probe 'echo "DNT=[$DO_NOT_TRACK] DT=[$DISABLE_TELEMETRY] sh=$(ps -o comm= -p $$)"'
check "restores the vars and runs \$SHELL when it is bash" "DNT=[1] DT=[1] sh=bash" \
    (env -u DO_NOT_TRACK -u DISABLE_TELEMETRY SHELL=(command -s bash) $helper $probe)
check "falls back to bash for any other \$SHELL" "DNT=[1] DT=[1] sh=bash" \
    (env -u DO_NOT_TRACK -u DISABLE_TELEMETRY SHELL=(command -s fish) $helper $probe)
if command -q zsh
    check "runs \$SHELL when it is zsh" "DNT=[1] DT=[1] sh=zsh" \
        (env -u DO_NOT_TRACK -u DISABLE_TELEMETRY SHELL=(command -s zsh) $helper $probe)
end
$helper 'exit 3'
check "exit status passes through" 3 $status

rm -rf $tmp
report
