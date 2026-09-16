#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for md: which flags it consumes, which it forwards verbatim,
# when it detaches, and the shape of the firejail read-only invocation.
#
# Runs isolated (no `# MODE:` marker). marktext, firejail and bkg are
# stubbed as functions that print their arguments, so the suite asserts on
# the assembled command line without launching an editor -- and passes on
# a machine that has none of the three installed.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

# Stubs. `type -q` is satisfied by a function, so md takes the same
# branches it would with the real binaries present.
function marktext
    echo "FG: $argv"
end
function firejail
    echo "FJ: $argv"
end
function bkg
    echo "BKG: $argv"
end

set -l sandbox (path resolve (mktemp -d))
set -l doc $sandbox/note.md
echo '# note' >$doc

# Keep the read-only user-data directory out of the real ~/.cache.
set -gx XDG_CACHE_HOME $sandbox/cache

section "md: forwarding and detaching"

check "plain file detaches via bkg" "BKG: marktext $doc" (md $doc)
check "--foreground runs in place" "FG: $doc" (md --foreground $doc)
check "--foreground is never forwarded" "FG: $doc" (md --foreground $doc)
check "marktext flags pass through" "BKG: marktext --new-window $doc" (md --new-window $doc)

section "md: output flags imply --foreground"

check "version flag" "FG: --version" (md --version)
check "verbose flag" "FG: --verbose $doc" (md --verbose $doc)
check "--debug after our own flag" "FG: --debug $doc" (md --foreground --debug $doc)

section "md: --read-only"

set -l ro (md -r $doc)
check "-r sandboxes with firejail" true (string match -q 'BKG: firejail *' -- $ro; and echo true; or echo false)
check "-r binds the file read-only" true (string match -q "*--read-only=$doc*" -- $ro; and echo true; or echo false)
check "-r is not forwarded to marktext" false (string match -q '* -r *' -- $ro; and echo true; or echo false)
check "-r forces a private instance" true (string match -q "*--user-data-dir=$XDG_CACHE_HOME/marktext-readonly*" -- $ro; and echo true; or echo false)
check "-r still passes the file" true (string match -q "*marktext *$doc" -- $ro; and echo true; or echo false)
check "--read-only is the same flag" true (string match -q 'BKG: firejail *' -- (md --read-only $doc); and echo true; or echo false)

# Relative paths must reach firejail absolute.
set -l start $PWD
cd $sandbox
check "-r resolves a relative path" true (string match -q "*--read-only=$doc*" -- (md -r note.md); and echo true; or echo false)
cd $start

check "-r without an existing file fails" 1 (md -r $sandbox/absent.md 2>/dev/null; echo $status)
check "-r can be combined with --foreground" true (string match -q 'FJ: *' -- (md -r --foreground $doc); and echo true; or echo false)

functions -e marktext firejail bkg
set -e XDG_CACHE_HOME
rm -rf $sandbox

report
