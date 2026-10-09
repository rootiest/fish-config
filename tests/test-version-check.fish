#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the minimum-Fish-version warning (issue #236):
# functions/__fish_config_version_check.fish and conf.d/00-version-check.fish.
#
# The function is called directly with a table of version strings. The conf.d
# file reads the read-only $version, so its behaviour is exercised in child
# fish processes that source a copy with the version literal swapped in; the
# real $version of the running fish goes through the untouched file.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx TERM xterm-256color

set -g sandbox (mktemp -d)
mkdir -p $sandbox/home $sandbox/data $sandbox/cfg $sandbox/cache

# Strip colour escapes so assertions do not depend on the palette.
# Strip colour escapes from stdin. `command cat |` makes the stdin read
# explicit: a function whose whole body is a bare `string replace PAT ''` does
# not see the pipe it is fed (verified on fish 4.9.3).
function _plain
    command cat | string replace -ra '\e\[[0-9;]*m' ''
end

# ---- the function: version table -------------------------------------------
section "version check: table"
# "version:expected status". Newer-than-minimum and git-describe/beta suffixes
# pass; older, empty and unparseable input fail.
set -l rows \
    4.0.0:0 4.0.1:0 4.1.0:0 4.9.3:0 5.0.0:0 10.2.1:0 \
    4:0 4.0:0 v4.0.0:0 4.0b1:0 4.1.0-12-gabc1234:0 99999999999999999999:0 \
    3.7.1:1 3.99.99:1 3.0:1 3:1 2.7.1:1 0.0.0:1 3.7.1-5-gabc1234:1 3.9b2:1 \
    :1 banana:1 ...:1 -1:1 .4:1 v:1 x4.0.0:1
for row in $rows
    set -l f (string split -m1 : -- $row)
    set -l err (__fish_config_version_check "$f[1]" 2>&1 >/dev/null)
    set -l st $status
    set -l out (__fish_config_version_check "$f[1]" 2>/dev/null)
    check "'$f[1]' -> status" $f[2] $st
    if test "$f[2]" = 0
        check "'$f[1]' -> silent" 0 (count $err)
    else
        check "'$f[1]' -> one message on stderr" true (test (count $err) -gt 0; and echo true; or echo false)
    end
    check "'$f[1]' -> nothing on stdout" 0 (count $out)
end

check "no argument is treated as unparseable" 1 (__fish_config_version_check 2>/dev/null; echo $status)

# ---- the function: message content -----------------------------------------
section "version check: message"
set -l msg (__fish_config_version_check 3.7.1 2>&1 >/dev/null | _plain)
set -l joined (string join \n -- $msg)
check "message is one block of 2 lines" 2 (count $msg)
check "message names the version found" true (string match -q '*3.7.1*' -- $joined; and echo true; or echo false)
check "message states the requirement" true (string match -q '*Fish 4.0.0 or newer is required*' -- $joined; and echo true; or echo false)
check "message points at fish-deps" true (string match -q '*fish-deps*' -- $joined; and echo true; or echo false)
check "message points at the troubleshooting section" true \
    (string match -q "*Fish Version Requirement*troubleshooting*" -- $joined; and echo true; or echo false)
check "message is attributed to fish-config" 1 (string match -r 'fish-config:' -- $msg | count)

set -l msg (__fish_config_version_check banana 2>&1 >/dev/null | _plain)
check "unparseable input is quoted in the message" true \
    (string match -q "*'banana'*" -- (string join \n -- $msg); and echo true; or echo false)
set -l msg (__fish_config_version_check "" 2>&1 >/dev/null | _plain)
check "empty input is reported as unknown" true \
    (string match -q '*unknown version*' -- (string join \n -- $msg); and echo true; or echo false)

# ---- the function: garbage raises no fish errors ---------------------------
section "version check: garbage input"
# Fish reports its own script errors on the process's stderr, which a command
# substitution here cannot capture, so this runs in a child fish. Every line
# must be our message or the rc= marker; anything else is a fish error.
set -l garbage "" banana ... -1 4. .4 v 4,0 1e9 '4 0 0' 99999999999999999999 '*' '(x)' '$HOME' 0000000000000000000
set -l out (fish --no-config -c '
    set -p fish_function_path '$repo_root'/functions
    for g in $argv
        __fish_config_version_check $g
        echo rc=$status
    end' -- $garbage 2>&1 | _plain)
check "garbage: one rc per input" (count $garbage) (string match -r '^rc=' -- $out | count)
set -l stray (string match -rv '^(rc=\d+|fish-config: .*|  Some features will fail.*)$' -- $out)
check "garbage: no stray or error output" "" "$stray"

# ---- conf.d: warns once, interactive only ----------------------------------
section "version check: conf.d file"
set -g confd $repo_root/conf.d/00-version-check.fish

# Count "fish-config:" lines that a child fish prints after sourcing the conf.d
# file N times with $version replaced by VER. FLAG is --interactive or -N.
function _probe --argument-names ver flag times
    set -l f $sandbox/conf-$ver.fish
    string replace -- '__fish_config_version_check $version' "__fish_config_version_check '$ver'" <$confd >$f
    set -l body "set -p fish_function_path $repo_root/functions; "(string repeat -n $times "source $f; ")
    env HOME=$sandbox/home XDG_DATA_HOME=$sandbox/data XDG_CONFIG_HOME=$sandbox/cfg \
        XDG_CACHE_HOME=$sandbox/cache fish --no-config $flag -c $body 2>&1 \
        | _plain | string match -r 'fish-config:' | count
end

check "the version literal could be swapped for the probe" true \
    (string match -q '*__fish_config_version_check $version*' <$confd; and echo true; or echo false)

check "old fish, interactive: warns" 1 (_probe 3.7.1 --interactive 1)
check "old fish, interactive, sourced twice: warns once" 1 (_probe 3.7.1 --interactive 2)
check "old fish, non-interactive: silent" 0 (_probe 3.7.1 --no-config 1)
check "supported fish, interactive: silent" 0 (_probe 4.0.0 --interactive 1)
check "newer fish, interactive: silent" 0 (_probe 4.9.3 --interactive 2)

# ---- the real fish ---------------------------------------------------------
section "version check: running fish"
__fish_config_version_check $version 2>/dev/null
check "the running fish ($version) is supported" 0 $status
set -l real (fish --no-config --interactive -c "set -p fish_function_path $repo_root/functions; source $confd" \
    2>&1 </dev/null | _plain | string match -r 'fish-config:' | count)
check "unmodified conf.d file is silent on the running fish" 0 $real

command rm -rf $sandbox
report
