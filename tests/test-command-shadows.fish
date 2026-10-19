#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for __fish_config_shadows_write and its catalog,
# data/command-shadows.tsv: the catalog stays in step with the shadow lint
# and the component registry, the JSON parses, enabled follows the toggles,
# and --if-stale rewrites only when a universal toggle changed.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish

# __fish_config_dir is read-only and points into the temp XDG dir; give it
# the fork's catalog.
command mkdir -p $__fish_config_dir
ln -sfn $repo_root/data $__fish_config_dir/data

set -g sandbox (mktemp -d)
set -g out $sandbox/command-shadows.json

# Prints one field of one shadow, as Python's json reads it.
function _field --argument-names name field
    python3 -I -c '
import json, sys
for s in json.load(open(sys.argv[1]))["shadows"]:
    if s["name"] == sys.argv[2]:
        print(json.dumps(s[sys.argv[3]]))
        break
' $out $name $field
end

section "command-shadows: catalog"
set -l rows (string match -rv '^\s*(#|$)' <$repo_root/data/command-shadows.tsv)
set -l names
set -l bad
for row in $rows
    set -l f (string split \t -- $row)
    test (count $f) -eq 8; or set -a bad "$f[1]: "(count $f)" columns"
    contains -- "$f[6]" 0 1; or set -a bad "$f[1]: breaks is '$f[6]'"
    set -l site $f[3]
    test "$site" = -; and set site ''
    if test "$f[2]" != -
        __fish_config_op_registry_lookup $f[2] $site >/dev/null
        or set -a bad "$f[1]: no registry entry for $f[2]:$site"
    end
    set -a names $f[1]
end
check "every row has 8 columns, a 0/1 breaks, and a registry entry" "" "$bad"

set -l lint (string match -rg '^set -l shadow_names (.*)' <$repo_root/tests/run-tests.fish | string split ' ')
set -l missing
for n in $lint
    contains -- $n $names; or set -a missing $n
end
check "found the shadow lint's name list in run-tests.fish" true (set -q lint[5]; and echo true; or echo false)
check "covers every name the shadow lint knows" "" "$missing"

section "command-shadows: generated JSON"
__fish_config_shadows_write --output $out
check "writes the file" 0 $status

if type -q python3
    check "parses, one object per catalog row" (count $rows) \
        (python3 -I -c 'import json, sys; print(len(json.load(open(sys.argv[1]))["shadows"]))' $out)
    check "ssh: on by default" true (_field ssh enabled)
    check "ssh: breaks scripts" true (_field ssh breaks_scripts)
    check "ssh: needs kitty" '"kitty, kitten installed"' (_field ssh when)
    check "ssh: toggle from the registry" '"__fish_config_op_aliases_network"' (_field ssh toggle)
    check "grep: cosmetic" false (_field grep breaks_scripts)
    check "less: no why is null" null (_field less why)
    check "split: no toggle removes it" null (_field split toggle)

    set -g __fish_config_op_aliases_network off
    __fish_config_shadows_write --output $out
    check "ssh: off with its sub-category" false (_field ssh enabled)
    check "split: still on" true (_field split enabled)
    set -e __fish_config_op_aliases_network

    set -g __fish_config_opinionated 0
    __fish_config_shadows_write --output $out
    check "rm: off with the master switch" false (_field rm enabled)
    set -e __fish_config_opinionated
else
    echo "  SKIP  python3 not installed"
end

section "command-shadows: --if-stale"
__fish_config_shadows_write --output $out
echo stale-marker >$out
__fish_config_shadows_write --if-stale --output $out
check "unchanged toggles: no rewrite" stale-marker (cat $out)

set -g __fish_config_op_aliases_network off
__fish_config_shadows_write --if-stale --output $out
check "a session override is not a universal change" stale-marker (cat $out)
set -e __fish_config_op_aliases_network

# --no-config turns set -U into a global, so stand in for a universal
# change by making the saved fingerprint differ.
echo older-state >$out.fp
__fish_config_shadows_write --if-stale --output $out
check "a changed fingerprint: rewritten" false (string match -q stale-marker -- (cat $out); and echo true; or echo false)

command rm -f $out
__fish_config_shadows_write --if-stale --output $out
check "a missing file: written" true (test -s $out; and echo true; or echo false)

command rm -rf $sandbox
report
