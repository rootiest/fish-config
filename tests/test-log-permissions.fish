#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for issue #223: terminal logs (C5) and the agent vault are private
# whatever the umask. Directories are 700 and files 600; a pre-existing laxer
# directory is tightened silently the next time it is used.
#
# Runs isolated (no `# MODE:` marker), under `umask 022` and a throwaway HOME /
# SCROLLBACK_HISTORY_DIR. Neither tmux, zellij nor kitty is required: the
# multiplexers are fake functions and the Kitty watcher is driven through
# stubbed `kitty` modules. Modes are read with `stat -c %a`.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -g TMPDIRS
function mode --argument-names p
    command stat -c %a -- $p
end

# Everything below must hold under the common permissive umask.
set -l saved_umask (umask)
umask 022

#   ─────────────────────────── _private_dir ───────────────────────────
section "log permissions: _private_dir"

set -l base (mktemp -d)
set -ga TMPDIRS $base

_private_dir $base/new/leaf
check "creates a missing directory" 0 $status
check "new directory is 700 under umask 022" 700 (mode $base/new/leaf)

mkdir -m 755 $base/lax
echo x >$base/lax/a.log
chmod 644 $base/lax/a.log
mkdir -m 755 $base/lax/sub
echo y >$base/lax/sub/b.log
chmod 644 $base/lax/sub/b.log
echo z >$base/outside.txt
chmod 644 $base/outside.txt
ln -s $base/outside.txt $base/lax/link.log

set -l out (_private_dir $base/lax 2>&1)
check "tighten without 'files': silent" "" "$out"
check "tighten without 'files': dir is 700" 700 (mode $base/lax)
check "tighten without 'files': files untouched" 644 (mode $base/lax/a.log)

chmod 755 $base/lax
set out (_private_dir $base/lax files 2>&1)
check "tighten with 'files': silent" "" "$out"
check "tighten with 'files': dir is 700" 700 (mode $base/lax)
check "tighten with 'files': file is 600" 600 (mode $base/lax/a.log)
check "subdirectory is left alone" 755 (mode $base/lax/sub)
check "nested file is left alone" 644 (mode $base/lax/sub/b.log)
check "symlink target is left alone" 644 (mode $base/outside.txt)

# Already 700: no walk, so a 644 file stays (the dir mode is what protects it).
echo q >$base/lax/c.log
chmod 644 $base/lax/c.log
_private_dir $base/lax files
check "already-private dir is not walked" 644 (mode $base/lax/c.log)

_private_dir ''
check "empty path fails" 1 $status

#   ───────────────────────────── tmux writer ─────────────────────────────
section "log permissions: _tmux_pipe_log"

set -g __pipe_cmd
function tmux
    switch "$argv[1]"
        case display-message
            if test "$argv[3]" = '#{session_name}'
                echo work
            else
                echo w0-p0
            end
        case pipe-pane
            set -g __pipe_cmd "$argv[2]"
    end
end
set -gx TMUX fake

# A directory that does not exist yet: created 700, log file created 600.
set -gx SCROLLBACK_HISTORY_DIR $base/tmux-new
_tmux_pipe_log
check "tmux: new log dir is 700" 700 (mode $SCROLLBACK_HISTORY_DIR)
echo hi | sh -c "$__pipe_cmd"
set -l made (command ls -1 $SCROLLBACK_HISTORY_DIR)
check "tmux: one log created" 1 (count $made)
check "tmux: log file is 600 under umask 022" 600 (mode $SCROLLBACK_HISTORY_DIR/$made[1])
check "tmux: log still receives output" hi (cat $SCROLLBACK_HISTORY_DIR/$made[1])

# An existing 755 directory holding a 644 log: tightened on use, silently.
set -gx SCROLLBACK_HISTORY_DIR $base/tmux-lax
mkdir -m 755 $SCROLLBACK_HISTORY_DIR
echo old >$SCROLLBACK_HISTORY_DIR/tmux_old_2026-01-01_00-00-00.log
chmod 644 $SCROLLBACK_HISTORY_DIR/tmux_old_2026-01-01_00-00-00.log
set out (_tmux_pipe_log 2>&1)
check "tmux: tightening prints nothing" "" "$out"
check "tmux: existing 755 dir becomes 700" 700 (mode $SCROLLBACK_HISTORY_DIR)
check "tmux: existing log becomes 600" 600 (mode $SCROLLBACK_HISTORY_DIR/tmux_old_2026-01-01_00-00-00.log)

functions -e tmux
set -e TMUX
set -e SCROLLBACK_HISTORY_DIR

#   ──────────────────────────── zellij writer ────────────────────────────
section "log permissions: _zellij_dump_log"

function zellij
    echo "pane contents"
end
set -gx ZELLIJ 0
set -gx ZELLIJ_SESSION_NAME sess
set -gx ZELLIJ_PANE_ID 1
set -gx __fish_config_op_logging 1

set -gx SCROLLBACK_HISTORY_DIR $base/zj-new
_zellij_dump_log
set made (command ls -1 $SCROLLBACK_HISTORY_DIR)
check "zellij: one log created" 1 (count $made)
check "zellij: new log dir is 700" 700 (mode $SCROLLBACK_HISTORY_DIR)
check "zellij: log file is 600 under umask 022" 600 (mode $SCROLLBACK_HISTORY_DIR/$made[1])
check "zellij: umask restored" 0022 (umask)

set -gx SCROLLBACK_HISTORY_DIR $base/zj-lax
mkdir -m 755 $SCROLLBACK_HISTORY_DIR
echo old >$SCROLLBACK_HISTORY_DIR/zellij_old_2026-01-01_00-00-00.log
chmod 644 $SCROLLBACK_HISTORY_DIR/zellij_old_2026-01-01_00-00-00.log
set out (_zellij_dump_log 2>&1)
check "zellij: tightening prints nothing" "" "$out"
check "zellij: existing 755 dir becomes 700" 700 (mode $SCROLLBACK_HISTORY_DIR)
check "zellij: existing log becomes 600" 600 (mode $SCROLLBACK_HISTORY_DIR/zellij_old_2026-01-01_00-00-00.log)

functions -e zellij
set -e ZELLIJ
set -e ZELLIJ_SESSION_NAME
set -e ZELLIJ_PANE_ID
set -e __fish_config_op_logging
set -e SCROLLBACK_HISTORY_DIR

#   ─────────────────────────── Kitty watcher ───────────────────────────
section "log permissions: Kitty scrollback watcher"

if type -q python3
    set -l pyhome (mktemp -d)
    set -ga TMPDIRS $pyhome
    # Stub the `kitty` package and drive save_scrollback_safely directly.
    set -l driver "
import importlib.util, os, sys, types
for name in ('kitty', 'kitty.boss', 'kitty.window'):
    sys.modules[name] = types.ModuleType(name)
sys.modules['kitty.boss'].Boss = object
sys.modules['kitty.window'].Window = object

spec = importlib.util.spec_from_file_location('w', sys.argv[1])
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)

class Child:
    foreground_processes = []

class Win:
    id = 1
    user_vars = {}
    child = Child()
    def as_text(self, as_ansi=False, add_history=False):
        return 'scrollback text'

w.save_scrollback_safely(Win())
"
    set -l watcher $repo_root/scripts/kitty-fish-config-watcher.py

    set -l d $pyhome/new
    HOME=$pyhome XDG_CONFIG_HOME=$pyhome/cfg SCROLLBACK_HISTORY_DIR=$d python3 -I -c $driver $watcher
    set made (command ls -1 $d 2>/dev/null)
    check "kitty: one log created" 1 (count $made)
    check "kitty: new log dir is 700" 700 (mode $d)
    check "kitty: log file is 600 under umask 022" 600 (mode $d/$made[1])

    set d $pyhome/lax
    mkdir -m 755 $d
    echo old >$d/scrollback_2026-01-01_00-00-00.log
    chmod 644 $d/scrollback_2026-01-01_00-00-00.log
    HOME=$pyhome XDG_CONFIG_HOME=$pyhome/cfg SCROLLBACK_HISTORY_DIR=$d python3 -I -c $driver $watcher
    check "kitty: existing 755 dir becomes 700" 700 (mode $d)
    check "kitty: existing log becomes 600" 600 (mode $d/scrollback_2026-01-01_00-00-00.log)
else
    echo "  SKIP  python3 not available"
end

#   ───────────────────────────── agent vault ─────────────────────────────
section "log permissions: agents-vault"

if type -q git
    set -gx GIT_AUTHOR_NAME t
    set -gx GIT_AUTHOR_EMAIL t@t
    set -gx GIT_COMMITTER_NAME t
    set -gx GIT_COMMITTER_EMAIL t@t
    set -gx GIT_CONFIG_COUNT 2
    set -gx GIT_CONFIG_KEY_0 commit.gpgsign
    set -gx GIT_CONFIG_VALUE_0 false
    set -gx GIT_CONFIG_KEY_1 init.defaultBranch
    set -gx GIT_CONFIG_VALUE_1 main

    set -l vhome (mktemp -d)
    set -ga TMPDIRS $vhome
    mkdir -p $vhome/claude $vhome/agy $vhome/work
    set -g __fish_agent_vault_claude_home $vhome/claude
    set -g __fish_agent_vault_claude_root $vhome/claude/projects
    set -g __fish_agent_vault_agy_root $vhome/agy

    # Fresh vault: created 700.
    set -g __fish_agent_vault_dir $vhome/fresh/agent-vault
    pushd $vhome/work >/dev/null
    agents-vault --silent
    set -l rc $status
    popd >/dev/null
    check "vault: run succeeds" 0 $rc
    check "vault: new root is 700 under umask 022" 700 (mode $__fish_agent_vault_dir)
    check "vault: is a working git repo" true (git -C $__fish_agent_vault_dir rev-parse --git-dir >/dev/null 2>&1; and echo true; or echo false)
    check "vault: .version is 600" 600 (mode $__fish_agent_vault_dir/.version)

    # Existing 755 vault (pre-fix layout): tightened silently, repo intact.
    chmod 755 $__fish_agent_vault_dir
    chmod 644 $__fish_agent_vault_dir/.version
    set -l before_objs (mode $__fish_agent_vault_dir/.git)
    pushd $vhome/work >/dev/null
    set out (agents-vault --silent 2>&1)
    set rc $status
    popd >/dev/null
    check "vault: laxer root: run succeeds" 0 $rc
    check "vault: laxer root: silent" "" "$out"
    check "vault: laxer root becomes 700" 700 (mode $__fish_agent_vault_dir)
    check "vault: top-level file becomes 600" 600 (mode $__fish_agent_vault_dir/.version)
    check "vault: .git left alone" $before_objs (mode $__fish_agent_vault_dir/.git)
    check "vault: git still works after tightening" true (git -C $__fish_agent_vault_dir status --porcelain >/dev/null 2>&1; and echo true; or echo false)

    set -e __fish_agent_vault_dir
    set -e __fish_agent_vault_claude_home
    set -e __fish_agent_vault_claude_root
    set -e __fish_agent_vault_agy_root
else
    echo "  SKIP  git not available"
end

umask $saved_umask
for d in $TMPDIRS
    command rm -rf $d
end

report
