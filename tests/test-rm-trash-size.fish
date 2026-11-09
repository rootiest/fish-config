#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the trash size summary that rm (functions/rm.fish) prints after
# listing the trash, computed by functions/__rm_trash_size.fish. A stub trash
# stands in for the real listing; the sizes come from the real du against a
# throwaway XDG_DATA_HOME and throwaway mount points.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish
set -gx NO_COLOR 1

set -g tmp (command mktemp -d)
set -g uid (command id -u)
set -gx XDG_DATA_HOME $tmp/data
set -gx STUB_STATUS 0

command mkdir -p $tmp/stub
printf '%s\n' '#!/bin/sh' 'echo "stub listing"' 'exit "$STUB_STATUS"' >$tmp/stub/trash
command chmod +x $tmp/stub/trash
set -gx PATH $tmp/stub $PATH

# fill DIR: a trash directory with one payload file and one .trashinfo record.
function fill --argument-names dir
    command mkdir -p $dir/files $dir/info
    command head -c 2097152 /dev/zero >$dir/files/payload
    command head -c 8192 /dev/zero >$dir/info/payload.trashinfo
end

# hsize PATH...: the grand total du reports for PATH...
function hsize
    string split -f1 \t (command du -shc $argv)[-1]
end

# Pass a mount point that holds nothing, so results never depend on the host.
set -g no_mount $tmp/no-mount
command mkdir -p $no_mount

section "__rm_trash_size: no trash directory"

check "prints nothing when no trash exists" "" (__rm_trash_size $no_mount)
check "exits 0 when no trash exists" 0 (__rm_trash_size $no_mount >/dev/null; echo $status)

section "__rm_trash_size: home trash"

set -l home_trash $XDG_DATA_HOME/Trash
fill $home_trash
set -l want "Trash Size: "(hsize $home_trash)" (files: "(hsize $home_trash/files)", info: "(hsize $home_trash/info)")"
set -l got (__rm_trash_size $no_mount)
check "reports the total, files, and info sizes" "$want" "$got[2]"
check "separates the summary from the listing" "" "$got[1]"

section "__rm_trash_size: XDG_DATA_HOME fallback"

set -g fake_home $tmp/home
fill $fake_home/.local/share/Trash
set -l want_size (hsize $fake_home/.local/share/Trash)
set -l got (env -u XDG_DATA_HOME HOME=$fake_home NO_COLOR=1 fish --no-config -c "
    set -p fish_function_path $repo_root/functions
    __rm_trash_size $no_mount")
check "falls back to ~/.local/share" "Trash Size: $want_size" (string replace -r ' \(.*' '' -- "$got[2]")

section "__rm_trash_size: per-volume trash"

set -l vol $tmp/vol
fill $vol/.Trash-$uid
set -l got (__rm_trash_size $vol)
check "counts \$top/.Trash-\$uid" "Trash Size: "(hsize $home_trash $vol/.Trash-$uid) (string replace -r ' \(.*' '' -- "$got[2]")

set -l shared $tmp/shared
fill $shared/.Trash/$uid
command chmod +t $shared/.Trash
set -l got (__rm_trash_size $shared)
check "counts a sticky \$top/.Trash/\$uid" "Trash Size: "(hsize $home_trash $shared/.Trash/$uid) (string replace -r ' \(.*' '' -- "$got[2]")

command chmod -t $shared/.Trash
set -l got (__rm_trash_size $shared)
check "ignores \$top/.Trash without the sticky bit" "Trash Size: "(hsize $home_trash) (string replace -r ' \(.*' '' -- "$got[2]")

section "rm: no arguments"

set -l got (rm)
check "lists the trash first" "stub listing" "$got[2]"
check "ends with the size summary" 1 (string match -q 'Trash Size: *' -- "$got[-1]"; and echo 1; or echo 0)

set -gx STUB_STATUS 3
rm >/dev/null
check "keeps the exit status of trash list" 3 $status
set -gx STUB_STATUS 0

command rm -rf $tmp
report
