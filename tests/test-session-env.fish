#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for session-env and its catalog, data/session-env.tsv.
#
# Runs isolated (no `# MODE:` marker): XDG_CONFIG_HOME is a temp dir, so the
# environment.d file is written there, never into the real ~/.config. When
# systemd's environment.d generator is installed, written files are also
# parsed by it, which is the only real proof the escaping is right.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

# __fish_config_dir is read-only and points into the temp XDG dir; give it
# the fork's catalog.
mkdir -p $__fish_config_dir
ln -sfn $repo_root/data $__fish_config_dir/data

set -l file $XDG_CONFIG_HOME/environment.d/fish-config.conf
set -g generator /usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator

# Print one variable as systemd would export it, given only HOME and PATH.
function _generated --argument-names name
    env -i HOME=/home/u PATH=/usr/bin XDG_CONFIG_HOME=$XDG_CONFIG_HOME $generator \
        | env -i sh -c "eval \"\$(cat)\"; printf '%s' \"\$$name\""
end

section "session-env: catalog"
set -l rows (string match -rv '^\s*(#|$)' <$repo_root/data/session-env.tsv)
set -l bad
set -l names
for r in $rows
    set -l f (string split \t -- $r)
    test (count $f) -eq 5; or set -a bad "$r"
    contains -- "$f[2]" 0 1; or set -a bad "$r"
    set -a names $f[3]
end
check "every row has 5 fields and a 0/1 default" "" "$bad"
check "variable names are unique" (count $names) (printf '%s\n' $names | sort -u | count)
check "only xdg is a default group" xdg \
    (string match -r '^[^\t]+\t1\t' -- $rows | string replace -r '\t.*' '' | sort -u)

section "session-env: install and status"
check "help exits 0" 0 (session-env --help >/dev/null; echo $status)
# fish reports script errors on its own stderr, which `2>&1` inside this
# process cannot capture, so list runs in a child fish for the error check.
set -l errs (fish --no-config -c "set -p fish_function_path $repo_root/functions; session-env list" 2>&1 >/dev/null)
check "list prints no fish errors" "" "$errs"
set -l listing (session-env list)
check "list tags the default group" true \
    (string match -q '*xdg*default*' -- (string replace -ra '\e\[[0-9;]*m' '' -- $listing); and echo true; or echo false)
check "status before install" true (session-env status | string match -q '*Not installed*'; and echo true; or echo false)

session-env install >/dev/null
check "install with no groups exits 0" 0 $status
check "default install holds the xdg group" "# groups: xdg" (string match '# groups:*' <$file)
check "default install writes the 4 base dirs" 4 (string match -rv '^\s*(#|$)' <$file | count)
check "literal entries fall back to the session value" 'XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME}/.config}' \
    (string match 'XDG_CONFIG_HOME=*' <$file)
check "status reports the groups" true (session-env status | string match -q '*Groups:*xdg*'; and echo true; or echo false)

section "session-env: copied values"
set -gx EDITOR 'ed $HOME "q" back\slash it\'s'
set -e VISUAL
set -l err (session-env install editor 2>&1 >/dev/null)
check "unexported copied variable is skipped with a warning" true \
    (string match -q '*Skipped VISUAL*' -- $err; and echo true; or echo false)
check "copied value is a quoted literal, no fallback" 'EDITOR="ed $$HOME \"q\" back\\\\slash it\'s"' \
    (string match 'EDITOR=*' <$file)
check "install replaces the previous groups" "# groups: editor" (string match '# groups:*' <$file)

section "session-env: self-referencing entries"
session-env install path >/dev/null
check "PATH entry is written as-is" 'PATH=${HOME}/.local/bin:${PATH}' (string match 'PATH=*' <$file)

if test -x $generator
    section "session-env: systemd parses the output"
    session-env install xdg editor path >/dev/null 2>&1
    check "copied value survives systemd unchanged" $EDITOR (_generated EDITOR)
    check "fallback default expands" /home/u/.local/state (_generated XDG_STATE_HOME)
    # The base PATH is host-dependent (/etc/environment may replace it), so
    # only the prefix is checked here; the case below pins the ordering.
    check "PATH gains the ~/.local/bin prefix" true \
        (string match -q '/home/u/.local/bin:*' -- (_generated PATH); and echo true; or echo false)
    # Ubuntu's /etc/environment (read via 99-environment.conf) sets an
    # absolute PATH; the managed file must sort after it to keep its prefix.
    echo PATH=/sim/bin >$XDG_CONFIG_HOME/environment.d/99-environment.conf
    check "PATH prefix survives a numbered file setting PATH" /home/u/.local/bin:/sim/bin (_generated PATH)
    rm $XDG_CONFIG_HOME/environment.d/99-environment.conf
end

section "session-env: errors and removal"
set -l before (string collect <$file)
session-env install xdg nope >/dev/null 2>&1
check "unknown group exits 1" 1 $status
check "unknown group leaves the file untouched" "$before" (string collect <$file)
check "preview prints without writing" "$before" (session-env preview wayland >/dev/null; string collect <$file)
check "preview output" 'MOZ_ENABLE_WAYLAND=${MOZ_ENABLE_WAYLAND:-1}' (session-env preview wayland | string match 'MOZ*')
session-env install help >/dev/null 2>&1
check "help is only a subcommand, not a group name" 1 $status
session-env bogus >/dev/null 2>&1
check "unknown command exits 1" 1 $status
session-env uninstall >/dev/null
check "uninstall removes the file" false (test -e $file; and echo true; or echo false)
session-env uninstall >/dev/null
check "uninstall with nothing installed exits 0" 0 $status

report
