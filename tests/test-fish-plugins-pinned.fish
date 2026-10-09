#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# fish_plugins pins (issue #248). Every Fisher-managed plugin must carry an
# explicit @ref so `fisher update` cannot pull an unreviewed default-branch
# commit, and the jorgebucaran/fisher pin must equal the _fisher_ref that
# conf.d/first_run.fish uses to bootstrap Fisher itself. Both values are
# parsed from the real files, never hardcoded here. Read-only: no network, no
# Fisher, no writes.

source (realpath (dirname (status filename)))/lib.fish

set -l plugins_file $repo_root/fish_plugins
set -l first_run $repo_root/conf.d/first_run.fish

# Non-comment, non-blank entries, whitespace-trimmed.
set -l entries (string match -rv -- '^\s*(#|$)' <$plugins_file | string trim)

section "fish_plugins: every entry is pinned"

check "fish_plugins has entries" true (test (count $entries) -gt 0; and echo true; or echo false)
for e in $entries
    check "$e has a non-empty @ref" true (string match -qr -- '^[^@\s]+/[^@\s]+@[^@\s]+$' $e; and echo true; or echo false)
    check "$e ref is not a floating branch name" false (string match -qr -- '@(HEAD|main|master|latest)$' $e; and echo true; or echo false)
end

section "fish_plugins: the Fisher pin matches first_run.fish _fisher_ref"

set -l fisher_ref (string match -rg -- '^\s*set -l _fisher_ref (\S+)\s*$' <$first_run)
check "_fisher_ref parsed from first_run.fish" true (test -n "$fisher_ref"; and echo true; or echo false)
set -l fisher_entry (string match -r -- '^jorgebucaran/fisher@.*$' $entries)
check "fish_plugins lists jorgebucaran/fisher" 1 (count $fisher_entry)
check "fisher pin equals _fisher_ref" "jorgebucaran/fisher@$fisher_ref" "$fisher_entry"

section "fish_plugins: consumers accept the pinned form"

# conf.d/sponge_privacy.fish and tests/run-tests.fish both detect sponge with
# the glob '*meaningful-ooo/sponge*'; it must still match the real, pinned line.
check "sponge entry present" 1 (count (string match -- 'meaningful-ooo/sponge@*' $entries))
check "sponge glob matches the pinned line" true (string match -q -- '*meaningful-ooo/sponge*' $entries; and echo true; or echo false)

# Fisher splits owner/repo@ref on '@' to build the tarball URL.
for e in $entries
    set -l parts (string split -- @ $e)
    check "$e splits into repo and ref" 2 (count $parts)
end

report
