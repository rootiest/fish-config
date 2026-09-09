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

report
