#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for tab completions: every function that parses options with
# `argparse` must ship a completions/<name>.fish, or be on the allow-list
# below. Fish derives nothing from argparse, so without a file the flags are
# simply undiscoverable -- and a new function would silently regress that.
#
# Also spot-checks a handful of the hand-written completions by asking a
# throwaway --no-config fish what `complete -C` offers with this repo's
# completions/ on its fish_complete_path.
#
# Runs isolated (no `# MODE:` marker).

source (realpath (dirname (status filename)))/lib.fish

# ---- Allow-list ------------------------------------------------------------
# A function that uses argparse but is exempt from needing a completion file.
# Internal helpers named with a leading underscore are exempt as a class (they
# are never typed by a user); anything else must be listed here BY NAME with a
# reason, so the exemption is a visible decision rather than an omission.
#
# Currently empty: every user-facing argparse function has a completion file.
set -l allow_list

section "argparse functions have a completion file"

set -l argparse_fns
for f in $repo_root/functions/*.fish
    set -l name (string replace -r '\.fish$' '' (path basename $f))
    # Non-comment lines only: a header that merely mentions argparse is no use.
    string match -rv '^\s*#' <$f | string match -rq '\bargparse\b'; or continue
    set -a argparse_fns $name
end

check "found argparse functions to check" true (test (count $argparse_fns) -gt 0; and echo true; or echo false)

for name in $argparse_fns
    if string match -q '_*' -- $name
        continue
    end
    if contains -- $name $allow_list
        continue
    end
    check "$name has completions/$name.fish" true (test -f $repo_root/completions/$name.fish; and echo true; or echo false)
end

section "completion files carry the license header"

# Only the hand-written files this check is about; vendored third-party
# completions keep their upstream attribution instead (CONTRIBUTING.md).
for name in $argparse_fns
    set -l file $repo_root/completions/$name.fish
    test -f $file; or continue
    set -l head (head -n 2 $file)
    # Vendored/adapted files keep upstream attribution; they carry no SPDX tag.
    string match -q '*Copyright*' -- $head[1]; or continue
    check "$name.fish SPDX header" "# SPDX-License-Identifier: AGPL-3.0-or-later" $head[2]
end

section "spot-check offered completions"

# What `complete -C "<line>"` offers, as a flat list of candidates.
#
# fish only autoloads completions/<cmd>.fish for a command it can resolve, and
# the child has no config, so these functions are not defined there. A stub
# function stands in for the command; the completion is what is under test.
function _offered --argument-names line
    set -l cmd (string split -f1 ' ' -- $line)
    env TERM=dumb fish --no-config -c \
        "set fish_complete_path $repo_root/completions \$fish_complete_path; function $cmd; end; complete -C '$line'" \
        | string split -f1 \t
end

set -l got (_offered 'mkrep --serv')
check "mkrep --serv -> --server" true (contains -- --server $got; and echo true; or echo false)

set -l got (_offered 'mkrep --server ')
check "mkrep --server <Tab> offers gitea" true (contains -- gitea $got; and echo true; or echo false)
check "mkrep --server <Tab> offers gitlab" true (contains -- gitlab $got; and echo true; or echo false)
check "mkrep --server <Tab> offers github" true (contains -- github $got; and echo true; or echo false)

set -l got (_offered 'mkrep --')
check "mkrep offers --new-remote" true (contains -- --new-remote $got; and echo true; or echo false)
check "mkrep offers --check-existing" true (contains -- --check-existing $got; and echo true; or echo false)

set -l got (_offered 'logs --category ')
check "logs --category <Tab> offers paru" true (contains -- paru $got; and echo true; or echo false)

set -l got (_offered 'git-clean -')
check "git-clean offers --force" true (contains -- --force $got; and echo true; or echo false)

set -l got (_offered 'gi --')
check "gi offers --custom" true (contains -- --custom $got; and echo true; or echo false)

set -l got (_offered 'agents-cleanup --')
check "agents-cleanup offers --dry-run" true (contains -- --dry-run $got; and echo true; or echo false)
check "agents-cleanup offers --marker-file" true (contains -- --marker-file $got; and echo true; or echo false)

# -w, -f and -i are mutually exclusive: once one is given, the rest are hidden.
set -l got (_offered 'gitignore-scrub --')
check "gitignore-scrub offers --warn alone" true (contains -- --warn $got; and echo true; or echo false)
set -l got (_offered 'gitignore-scrub --warn --')
check "gitignore-scrub --warn hides --force" false (contains -- --force $got; and echo true; or echo false)
check "gitignore-scrub --warn still offers --reset" true (contains -- --reset $got; and echo true; or echo false)

# --install/--uninstall must be the only argument.
set -l got (_offered 'key-crypt --')
check "key-crypt offers --install as the only argument" true (contains -- --install $got; and echo true; or echo false)
set -l got (_offered 'key-crypt --force --')
check "key-crypt hides --install after another flag" false (contains -- --install $got; and echo true; or echo false)

report
