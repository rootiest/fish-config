#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Gate for the curses config-settings PROTOTYPE (scripts/config-settings-tui.py).
#
# Runs isolated (no `# MODE:` marker). Two things are checked, and only two:
#
#   1. python3 can import `curses`. On Arch, Fedora and a full Debian/Ubuntu
#      python3 this is stdlib and always true, but python3-minimal alone does
#      not carry _curses -- the one portability claim the prototype makes.
#   2. The prototype's own --self-test passes. That covers the pure state
#      machine (value cycling, filtering, sub-category lookup, badge and
#      ellipsis rendering) with no TTY, which is all a test runner has.
#
# The drawing code is deliberately NOT golden-tested. That is the whole
# argument for the prototype: curses owns the cell arithmetic, so there is no
# hand-tuned width/pad/dash math to pin down the way
# test-config-settings-render.fish has to pin the fish renderer's.

source (dirname (status filename))/lib.fish

set -l tui $repo_root/scripts/config-settings-tui.py

section "config-settings-tui: prerequisites"
check "scripts/config-settings-tui.py is executable" true (test -x $tui; and echo true; or echo false)
check "python3 is available" true (type -q python3; and echo true; or echo false)
check "python3 ships the curses module" 0 (python3 -c 'import curses' >/dev/null 2>&1; echo $status)

section "config-settings-tui: self-test"
check "--self-test passes" 0 (python3 $tui --self-test >/dev/null 2>&1; echo $status)

report
