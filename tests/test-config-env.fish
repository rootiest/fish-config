#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for the environment setup in config.fish (issue #222):
#   * GPG_TTY is only exported when a controlling tty exists, never as the
#     literal text "not a tty"
#   * EXINIT carries no dangling `| source` with an empty target
#   * CLAUDE_CODE_NO_FLICKER honours the C3 (overrides) guard
#
# Runs isolated (no `# MODE:` marker). config.fish itself is far too heavy to
# execute here (Fisher bootstrap, distro config, plugins), so the three blocks
# under test are cut out of the real file by their guard lines and sourced
# from a throwaway file NAMED config.fish -- the guards identify themselves
# with (status basename), so the name is load-bearing. The extraction is
# anchored on the real source text, so a regression in config.fish turns the
# cases red, and an edit that moves a block out from under its anchor fails
# the "block found" preconditions rather than passing vacuously.

source (realpath (dirname (status filename)))/lib.fish

set -g work (mktemp -d)

# Print the block that starts at the first line matching $start and runs to
# the first following line equal to $close.
function _cut_block --argument-names start close
    set -l on 0
    while read -l line
        if test $on -eq 0
            string match -rq -- $start $line; and set on 1
        end
        if test $on -eq 1
            printf '%s\n' $line
            test "$line" = "$close"; and break
        end
    end <$repo_root/config.fish
end

section "config env: block extraction preconditions"

set -l exinit_src (string match -r -- '^set -q EXINIT;.*' <$repo_root/config.fish)
# Anchored on the four-space indent: the top-level pager/editor guard shares
# the same site name, only the interactive-block one sets GPG_TTY.
set -l gpg_src (_cut_block '^    if __fish_config_op_enabled .*pager-editor-gpg' '    end')
set -l flicker_src (_cut_block '^    if __fish_config_op_enabled .*claude-no-flicker' '    end')

check "EXINIT line found" true (test -n "$exinit_src"; and echo true; or echo false)
check "GPG_TTY block found" true (string match -q '*GPG_TTY*' -- $gpg_src; and echo true; or echo false)
check "NO_FLICKER block found" true (string match -q '*CLAUDE_CODE_NO_FLICKER*' -- $flicker_src; and echo true; or echo false)

printf '%s\n' $exinit_src >$work/exinit.fish
printf '%s\n' $gpg_src >$work/gpg.fish
printf '%s\n' $flicker_src >$work/flicker.fish
# Same text, but under the name the guards identify themselves with.
mkdir -p $work/exinit $work/gpg $work/flicker
cp $work/exinit.fish $work/exinit/config.fish
cp $work/gpg.fish $work/gpg/config.fish
cp $work/flicker.fish $work/flicker/config.fish

# Child preamble: the fork's guard code and registry, no guard variables.
set -g pre "set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish
set -e __fish_config_opinionated __fish_config_op_overrides __fish_config_op_overrides_environment GPG_TTY CLAUDE_CODE_NO_FLICKER
set -gx XDG_STATE_HOME $work/state
"

section "config env: GPG_TTY"

# setsid detaches from any controlling terminal; stdin from /dev/null on top
# makes `tty` fail exactly as it does under cron, systemd or `ssh host cmd`.
set -l out (command setsid -w fish --no-config -c "$pre
source $work/gpg/config.fish
set -q GPG_TTY; and echo \"SET=[\$GPG_TTY]\"; or echo UNSET" </dev/null 2>&1)
check "no tty: GPG_TTY is not exported" UNSET "$out"
check "no tty: never the literal 'not a tty'" false (string match -q '*not a tty*' -- $out; and echo true; or echo false)

# With a tty the value must be the real tty device. Needs a pty; python3's
# stdlib pty is already a prerequisite of the other suites.
set -l pty_runner '
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp("fish", ["fish", "--no-config", "-c", sys.argv[1]])
deadline, out = time.monotonic() + 15, b""
while time.monotonic() < deadline:
    if not select.select([fd], [], [], deadline - time.monotonic())[0]:
        break
    try:
        chunk = os.read(fd, 65536)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
os.waitpid(pid, 0)
sys.stdout.write(out.decode("utf-8", "replace"))
'
set -l pty_out (command python3 -I -c $pty_runner "$pre
source $work/gpg/config.fish
echo \"GOT=[\$GPG_TTY]\"" | string replace -a \r '')
check "tty: GPG_TTY is the real tty device" true \
    (string match -rq 'GOT=\[/dev/(pts/\d+|tty\S*)\]' -- $pty_out; and echo true; or echo false)

set -l out (command setsid -w fish --no-config -c "$pre
set -g __fish_config_op_overrides 0
source $work/gpg/config.fish
set -q GPG_TTY; and echo SET; or echo UNSET" </dev/null 2>&1)
check "overrides off: GPG_TTY is not set" UNSET "$out"

section "config env: EXINIT"

set -l out (command fish --no-config -c "$pre
set -e EXINIT
source $work/exinit/config.fish
echo \"[\$EXINIT]\"" 2>&1)
check "EXINIT sets viminfofile" "[set viminfofile=$work/state/vim/viminfo]" "$out"
check "EXINIT has no dangling source" false (string match -q '*source*' -- $out; and echo true; or echo false)
check "EXINIT does not end in a pipe" false (string match -rq '\|\s*\]$' -- $out; and echo true; or echo false)

set -l out (command fish --no-config -c "$pre
set -gx EXINIT 'set mine'
source $work/exinit/config.fish
echo \"[\$EXINIT]\"" 2>&1)
check "a user-set EXINIT is left alone" "[set mine]" "$out"

section "config env: CLAUDE_CODE_NO_FLICKER (C3 overrides)"

function _flicker --argument-names setup
    command fish --no-config -c "$pre
$setup
source $work/flicker/config.fish
set -q CLAUDE_CODE_NO_FLICKER; and echo \$CLAUDE_CODE_NO_FLICKER; or echo UNSET" 2>&1
end

check "default: exported as 1" 1 (_flicker '')
check "overrides off: not exported" UNSET (_flicker 'set -g __fish_config_op_overrides 0')
check "master switch off: not exported" UNSET (_flicker 'set -g __fish_config_opinionated 0')
check "environment sub-category off: not exported" UNSET (_flicker 'set -g __fish_config_op_overrides_environment 0')
check "explicit category on beats master off" 1 (_flicker 'set -g __fish_config_opinionated 0; set -g __fish_config_op_overrides 1')
check "registered in the C3 environment sub-category" overrides/environment \
    (begin
        set -p fish_function_path $repo_root/functions
        source $repo_root/conf.d/__fish_config_op_registry.fish
        __fish_config_op_registry_lookup config claude-no-flicker
    end)

command rm -rf $work
report
