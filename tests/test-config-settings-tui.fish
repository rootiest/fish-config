#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Gate for the curses config-settings front-end (scripts/config-settings-tui.py).
#
# Runs isolated (no `# MODE:` marker). Three things are checked here:
#
#   1. python3 can import `curses`. On Arch, Fedora and a full Debian/Ubuntu
#      python3 this is stdlib and always true, but python3-minimal alone does
#      not carry _curses -- the one portability claim config-settings makes,
#      and the reason the function checks the import rather than just `type -q`.
#   2. The TUI's own --self-test passes. That covers the state-dump parser,
#      variable-name derivation, toggle cycling, the sub-category-aware filter,
#      fish quoting and command emission, with no TTY.
#   3. config-settings still degrades cleanly with no terminal, rather than
#      leaving a half-initialised curses screen behind.
#
# The drawing code is deliberately NOT golden-tested, and the golden harness
# the ANSI renderer needed is gone. That is the point of the rewrite: curses
# owns the cell arithmetic, so there is no hand-tuned width/pad/dash maths left
# to pin down. The seam that does need pinning -- dump in, fish script out --
# is covered here and, for session scope, in tests/test-session.fish.

source (dirname (status filename))/lib.fish

# Isolated suites run under `fish --no-config`, which autoloads nothing from
# this repo. The launcher cases below call config-settings for real, so put the
# repo's functions on the autoload path -- and only that, so nothing in conf.d
# runs and the guard variables stay unset.
set -p fish_function_path $repo_root/functions

set -l tui $repo_root/scripts/config-settings-tui.py

section "config-settings-tui: prerequisites"
check "scripts/config-settings-tui.py is executable" true (test -x $tui; and echo true; or echo false)
check "python3 is available" true (type -q python3; and echo true; or echo false)
check "python3 ships the curses module" 0 (python3 -c 'import curses' >/dev/null 2>&1; echo $status)

section "config-settings-tui: self-test"
check "--self-test passes" 0 (python3 $tui --self-test >/dev/null 2>&1; echo $status)

section "config-settings: launcher"
check "--help exits 0" 0 (config-settings --help >/dev/null 2>&1; echo $status)
check "an unknown flag exits 1" 1 (config-settings --nope >/dev/null 2>&1; echo $status)

# stdout is a pipe here, so the isatty guard fires before curses ever starts.
# Without it the TUI would fail deep inside setupterm and leave the terminal
# in whatever state it got to.
function test_no_tty_is_refused_cleanly
    set -l out (config-settings 2>&1 >/dev/null | string collect)
    string match -q '*needs a terminal*' -- $out
end
check "no TTY is refused with a message, not a curses crash" true (test_no_tty_is_refused_cleanly; and echo true; or echo false)

# An empty state dump is the dangerous failure, because it is not one: the TUI
# would render every row as DEFAULT, which is indistinguishable from a config
# where nothing is set. The user would be looking at ON rows reported as OFF's
# neighbour and toggling from a false baseline. The launcher must refuse.
#
# Reaching that guard needs a real terminal -- the isatty check sits in front
# of it -- so this runs fish under a pty. python3 is already a hard
# prerequisite of this suite (see the header), so its stdlib pty module costs
# no new dependency; `script` would.
#
# The deadline is load-bearing, not belt-and-braces. If the guard regresses,
# config-settings does not fail -- it opens the TUI and blocks on getch(),
# so an unbounded read here would hang the suite instead of failing it.
set -l pty_runner '
import os, pty, select, signal, sys, time
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
else:
    out += b"\nTIMEOUT: the TUI opened and blocked on input\n"
try:
    os.kill(pid, signal.SIGKILL)
except ProcessLookupError:
    pass
os.waitpid(pid, 0)
sys.stdout.write(out.decode("utf-8", "replace"))
'

function test_empty_state_dump_is_refused --argument-names runner
    # Shadowing the autoloaded __config_settings_state with an empty function
    # is what fakes the failure; a real dump always carries the taxonomy.
    set -l cmd "set -p fish_function_path $repo_root/functions;
        function __config_settings_state; end;
        config-settings;
        echo RC=\$status"
    set -l out (python3 -c "$runner" "$cmd" | string collect)

    set -l failed 0
    if not string match -q '*produced no output*' -- $out
        # A regression here means the TUI drew itself, so $out is a screenful
        # of escape sequences. Strip them and keep a usable excerpt.
        set -l seen (string replace -ra '\e\[[0-9;?]*[a-zA-Z]|\e[()][A-Z]' '' -- $out \
            | string join ' ' | string sub -l 120)
        echo "    expected the empty-dump refusal, got: $seen"
        set failed 1
    end
    if not string match -q '*RC=1*' -- $out
        echo "    expected exit status 1 from the refusal"
        set failed 1
    end
    # Guard the guard: if the pty were not a terminal we would be watching the
    # isatty check fire and would learn nothing about the dump.
    if string match -q '*needs a terminal*' -- $out
        echo "    the isatty guard fired -- the pty did not present a terminal"
        set failed 1
    end
    test $failed -eq 0
end
check "an empty state dump is refused, not rendered as all-DEFAULT" true (test_empty_state_dump_is_refused "$pty_runner"; and echo true; or echo false)

report
