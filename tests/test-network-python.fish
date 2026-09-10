#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Isolated test suite for Python helper scripts network isolation and edge case mocking.
# Exercises scripts/sync-labels.py under offline conditions with full mock coverage.
#
# Runs isolated (no # MODE: marker, defaulting to isolated).

source (realpath (dirname (status filename)))/lib.fish

section "python network isolation: sync-labels.py"

set -l py_script $repo_root/tests/test_sync_labels.py
check "tests/test_sync_labels.py exists" true (test -f $py_script; and echo true; or echo false)

set -l py_lines (python3 $py_script -v 2>&1)
set -l py_status $status

for line in $py_lines
    if string match -qr '^\s*(test_\w+)\s+\([^)]+\)\s+\.\.\.\s+(\w+)' -- $line
        set -l match (string match -r '^\s*(test_\w+)\s+\([^)]+\)\s+\.\.\.\s+(\w+)' -- $line)
        set -l tname $match[2]
        set -l tres $match[3]
        check "$tname" ok (string lower $tres)
    end
end

check "test_sync_labels.py suite exited 0" 0 $py_status

report
