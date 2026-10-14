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
check "unknown group exits 2" 2 $status
check "unknown group leaves the file untouched" "$before" (string collect <$file)
check "preview prints without writing" "$before" (session-env preview wayland >/dev/null; string collect <$file)
check "preview output" 'MOZ_ENABLE_WAYLAND=${MOZ_ENABLE_WAYLAND:-1}' (session-env preview wayland | string match 'MOZ*')
session-env install help >/dev/null 2>&1
check "help is only a subcommand, not a group name" 2 $status
session-env bogus >/dev/null 2>&1
check "unknown command exits 2" 2 $status
session-env uninstall >/dev/null
check "uninstall removes the file" false (test -e $file; and echo true; or echo false)
session-env uninstall >/dev/null
check "uninstall with nothing installed exits 0" 0 $status

# ── Per-variable selection ──────────────────────────────────────────────
# Helper: ANSI-free output of a command, for substring checks.
function _plain
    string replace -ra '\e\[[0-9;]*m' '' -- $argv
end

section "session-env: per-variable selection"
session-env install xdg privacy --except DISABLE_TELEMETRY >/dev/null 2>&1
check "install with --except exits 0" 0 $status
check "partial selection records the groups" "# groups: xdg privacy" (string match '# groups:*' <$file)
check "partial selection records an exact vars line" \
    "# vars: XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME DO_NOT_TRACK" \
    (string match '# vars:*' <$file)
check "the excluded variable is not written" 0 (string match -r '^DISABLE_TELEMETRY=' <$file | count)
check "the group's other variable is written" 1 (string match -r '^DO_NOT_TRACK=' <$file | count)
check "status reports individual selection" true \
    (_plain (session-env status) | string match -q '*Selection: individual variables*'; and echo true; or echo false)
set -l listing (_plain (session-env list))
check "list marks a selected variable" true \
    (printf '%s\n' $listing | string match -rq '\[x\] DO_NOT_TRACK'; and echo true; or echo false)
check "list marks a deselected variable" true \
    (printf '%s\n' $listing | string match -rq '\[ \] DISABLE_TELEMETRY'; and echo true; or echo false)
check "list tags a partly selected group" true \
    (printf '%s\n' $listing | string match -rq '^privacy .*partial 1/2'; and echo true; or echo false)

session-env sync >/dev/null 2>&1
check "sync keeps the per-variable selection" "# vars: XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME DO_NOT_TRACK" \
    (string match '# vars:*' <$file)

session-env add DISABLE_TELEMETRY >/dev/null 2>&1
check "adding the missing variable completes the group" "# groups: xdg privacy" (string match '# groups:*' <$file)
check "a whole-group selection drops the vars line" 0 (string match '# vars:*' <$file | count)

session-env remove DO_NOT_TRACK >/dev/null 2>&1
check "remove narrows to a vars line again" 1 (string match '# vars:*' <$file | count)
session-env remove privacy >/dev/null 2>&1
check "remove accepts a group" 0 (string match -r '^(DO_NOT_TRACK|DISABLE_TELEMETRY)=' <$file | count)
check "remove of a whole group leaves the rest as whole groups" "# groups: xdg" (string match '# groups:*' <$file)
session-env add xdg-tools >/dev/null 2>&1
check "add accepts a group" true (string match -rq '^# groups: xdg xdg-tools$' <$file; and echo true; or echo false)

set -l before (string collect <$file)
session-env add NOT_A_VARIABLE >/dev/null 2>&1
check "add of an unknown name exits 2" 2 $status
check "add of an unknown name leaves the file alone" "$before" (string collect <$file)
session-env install --var NOT_A_VARIABLE >/dev/null 2>&1
check "install --var of an unknown name exits 2" 2 $status
session-env install xdg --except NOT_A_VARIABLE >/dev/null 2>&1
check "install --except of an unknown name exits 2" 2 $status
session-env install --bogus >/dev/null 2>&1
check "an unknown flag exits 2" 2 $status
session-env sync xdg >/dev/null 2>&1
check "sync rejects a selection" 2 $status
session-env preview xdg --now >/dev/null 2>&1
check "preview rejects --now" 2 $status
session-env add >/dev/null 2>&1
check "add with nothing exits 2" 2 $status
session-env remove xdg xdg-tools >/dev/null 2>&1
check "removing everything exits 2" 2 $status
check "removing everything leaves the file alone" "$before" (string collect <$file)
check "install --var alone selects just that variable" "XDG_CONFIG_HOME=\${XDG_CONFIG_HOME:-\${HOME}/.config}" \
    (session-env preview --var XDG_CONFIG_HOME | string match 'XDG_CONFIG_HOME=*')
check "a lone --var does not pull in the default group" 0 \
    (session-env preview --var XDG_CONFIG_HOME | string match 'XDG_DATA_HOME=*' | count)

section "session-env: files from before per-variable selection"
# A file with only "# groups:" selects every variable of those groups.
printf '%s\n' '# Managed by fish-config' '# groups: wayland' 'MOZ_ENABLE_WAYLAND=${MOZ_ENABLE_WAYLAND:-1}' >$file
check "status reads a groups-only file" true \
    (_plain (session-env status) | string match -q '*Selection: whole groups*'; and echo true; or echo false)
session-env remove SDL_VIDEODRIVER >/dev/null 2>&1
check "a legacy group expands to its variables on remove" \
    "# vars: MOZ_ENABLE_WAYLAND ELECTRON_OZONE_PLATFORM_HINT QT_QPA_PLATFORM _JAVA_AWT_WM_NONREPARENTING" \
    (string match '# vars:*' <$file)
check "the removed variable is gone" 0 (string match -r '^SDL_VIDEODRIVER=' <$file | count)
check "the others stay" 1 (string match -r '^MOZ_ENABLE_WAYLAND=' <$file | count)

# ── Staleness ───────────────────────────────────────────────────────────
section "session-env: staleness check"
session-env install editor >/dev/null 2>&1
set -gx EDITOR vim
set -gx VISUAL vim
set -gx PAGER less
set -gx MANPAGER less
set -gx BROWSER firefox
session-env install editor >/dev/null 2>&1
check "a fresh file is up to date" true \
    (_plain (session-env status) | string match -q '*up to date*'; and echo true; or echo false)
set -gx EDITOR nvim
set -l st (_plain (session-env status))
check "a changed copied value is reported stale" true \
    (string match -q '*Stale*' -- $st; and echo true; or echo false)
check "the stale variable is named with both values" true \
    (string match -q '*EDITOR: file has "vim", fish now has "nvim"*' -- $st; and echo true; or echo false)
session-env sync >/dev/null 2>&1
check "sync refreshes the snapshot" 'EDITOR="nvim"' (string match 'EDITOR=*' <$file)
check "sync keeps the groups" "# groups: editor" (string match '# groups:*' <$file)
check "after sync status is up to date" true \
    (_plain (session-env status) | string match -q '*up to date*'; and echo true; or echo false)
set -e BROWSER
check "a variable fish stopped exporting is reported" true \
    (_plain (session-env status) | string match -q '*BROWSER: in the file, but fish no longer exports*'; and echo true; or echo false)
session-env uninstall >/dev/null
session-env sync >/dev/null 2>&1
check "sync with nothing installed exits 1" 1 $status

# ── Apply now ───────────────────────────────────────────────────────────
section "session-env: apply now (stubbed systemctl and dbus)"
set -l tmp (mktemp -d)
set -l bin $tmp/bin
set -l calls $tmp/calls.log
mkdir -p $bin
printf '%s\n' '#!/bin/sh' "echo \"systemctl \$*\" >>$calls" \
    '[ "$2" = show-environment ] && printf "HOME=/home/u\nXDG_RUNTIME_DIR=/run/user/1\nDO_NOT_TRACK=0\n"' \
    'exit 0' >$bin/systemctl
printf '%s\n' '#!/bin/sh' "echo \"dbus \$*\" >>$calls" >$bin/dbus-update-activation-environment
chmod +x $bin/systemctl $bin/dbus-update-activation-environment
set -l saved_path $PATH
set -gx PATH $bin $PATH

session-env install xdg privacy >/dev/null 2>&1
check "install without --now runs neither command" false (test -e $calls; and echo true; or echo false)
session-env install xdg privacy --now >/dev/null 2>&1
check "install --now exits 0" 0 $status
set -l sc (string match 'systemctl --user set-environment*' <$calls)
check "systemctl set-environment was called" 1 (count $sc)
check "a literal is resolved against the manager environment" true \
    (string match -q '*XDG_CONFIG_HOME=/home/u/.config*' -- $sc; and echo true; or echo false)
check "a value the session already has is not overridden" false \
    (string match -q '*DO_NOT_TRACK=*' -- $sc; and echo true; or echo false)
check "an unset one is applied" true \
    (string match -q '*DISABLE_TELEMETRY=1*' -- $sc; and echo true; or echo false)
check "the D-Bus activation environment is updated too" 1 (string match 'dbus *' <$calls | count)
rm -f $calls
session-env apply >/dev/null 2>&1
check "apply exits 0" 0 $status
check "apply calls systemctl without rewriting the file" 1 (string match 'systemctl --user set-environment*' <$calls | count)
check "apply rejects a selection" 2 (session-env apply xdg >/dev/null 2>&1; echo $status)
session-env uninstall >/dev/null
rm -f $calls
session-env apply >/dev/null 2>&1
check "apply with nothing installed exits 1" 1 $status
check "apply with nothing installed calls nothing" false (test -e $calls; and echo true; or echo false)

# Neither tool installed: a PATH holding only the basics the function needs.
set -l sb $tmp/sbin
mkdir -p $sb
for t in printenv mkdir mv rm head grep env sh cat
    set -l real (command -s $t)
    test -n "$real"; and ln -sf $real $sb/$t
end
printf '%s\n' '# Managed' '# groups: xdg' >$file
set -l out (env PATH=$sb (command -s fish) --no-config -c \
    "set -p fish_function_path $repo_root/functions; session-env apply" 2>&1 | string collect)
set -l rc $pipestatus[1]
check "with neither tool installed apply exits 1" 1 $rc
check "and says so" true (string match -q '*neither systemctl nor dbus-update-activation-environment*' -- $out; and echo true; or echo false)
session-env uninstall >/dev/null
set -gx PATH $saved_path

# ── Expansion helper ────────────────────────────────────────────────────
section "session-env: environment.d expansion helper"
check "nested default with a value set" /c/go (__session_env_expand '${XDG_CACHE_HOME:-${HOME}/.cache}/go' HOME=/h XDG_CACHE_HOME=/c)
check "nested default falling through" /h/.cache/go (__session_env_expand '${XDG_CACHE_HOME:-${HOME}/.cache}/go' HOME=/h)
check "an empty value takes the default" /h/.cache (__session_env_expand '${X:-${HOME}/.cache}' HOME=/h X=)
check "plain reference" /h/.local/bin:/usr/bin (__session_env_expand '${HOME}/.local/bin:${PATH}' HOME=/h PATH=/usr/bin)
check "an unset reference without a default is empty" ab (__session_env_expand 'a${NOPE}b')
check '$$ is a literal dollar' 'a$b' (__session_env_expand 'a$$b')

# ── Desktop overrides ───────────────────────────────────────────────────
section "session-env: .desktop overrides"
set -l sysdir $tmp/sys
set -l userdata $tmp/userdata
mkdir -p $sysdir/applications
printf '%s\n' '[Desktop Entry]' 'Name=Claude' 'Exec=/opt/Claude/claude --no-sandbox %U' \
    'TryExec=/opt/Claude/claude' '' '[Desktop Action new]' 'Exec=/opt/Claude/claude --new' >$sysdir/applications/claude-desktop.desktop
set -l sys_sum (md5sum <$sysdir/applications/claude-desktop.desktop)
set -gx XDG_DATA_DIRS $sysdir
set -gx XDG_DATA_HOME $userdata
set -l dfile $userdata/applications/claude-desktop.desktop

check "status with none installed" true \
    (_plain (session-env desktop status) | string match -q '*No managed*'; and echo true; or echo false)
check "preview prints without writing" false \
    (session-env desktop preview claude-desktop >/dev/null; test -e $dfile; and echo true; or echo false)
check "preview prefixes the unset list on every Exec" 2 \
    (session-env desktop preview claude-desktop | string match -r '^Exec=env -u DO_NOT_TRACK -u DISABLE_TELEMETRY ' | count)
session-env desktop install claude-desktop >/dev/null 2>&1
check "install exits 0" 0 $status
check "the override lands in the user applications dir" true (test -f $dfile; and echo true; or echo false)
check "it starts with the marker" "# Managed by fish-config's session-env desktop" (head -n1 $dfile)
check "Exec lines are prefixed, arguments kept" 'Exec=env -u DO_NOT_TRACK -u DISABLE_TELEMETRY /opt/Claude/claude --no-sandbox %U' \
    (string match 'Exec=*--no-sandbox*' <$dfile)
check "TryExec is untouched" 'TryExec=/opt/Claude/claude' (string match 'TryExec=*' <$dfile)
check "the desktop-action Exec is prefixed too" 'Exec=env -u DO_NOT_TRACK -u DISABLE_TELEMETRY /opt/Claude/claude --new' \
    (string match 'Exec=*--new' <$dfile)
check "the system launcher is never modified" "$sys_sum" (md5sum <$sysdir/applications/claude-desktop.desktop)
check "status lists the override" true \
    (_plain (session-env desktop status) | string match -q '*claude-desktop.desktop*'; and echo true; or echo false)
session-env desktop install claude-desktop --var FOO --group wayland >/dev/null 2>&1
check "install again rewrites a managed file with the new set" true \
    (string match -q '*-u FOO -u MOZ_ENABLE_WAYLAND*' -- (string match 'Exec=*--new' <$dfile); and echo true; or echo false)
printf '\nExec=changed\n' >>$sysdir/applications/claude-desktop.desktop
check "status flags a changed system launcher" true \
    (_plain (session-env desktop status) | string match -q '*system launcher changed*'; and echo true; or echo false)
session-env desktop uninstall claude-desktop >/dev/null 2>&1
check "uninstall removes the override" false (test -e $dfile; and echo true; or echo false)
check "uninstall leaves the applications dir usable" true (test -d $userdata/applications; and echo true; or echo false)
session-env desktop uninstall claude-desktop >/dev/null 2>&1
check "uninstall with nothing there exits 0" 0 $status

# Unmanaged files are never overwritten or removed.
printf '%s\n' '[Desktop Entry]' 'Name=Hand edited' 'Exec=env -u X claude' >$dfile
set -l hand (md5sum <$dfile)
session-env desktop install claude-desktop >/dev/null 2>&1
check "install refuses to overwrite a hand-made copy" 1 $status
session-env desktop uninstall claude-desktop >/dev/null 2>&1
check "uninstall refuses to delete a hand-made copy" 1 $status
check "the hand-made copy is byte-identical" "$hand" (md5sum <$dfile)
rm -f $dfile

session-env desktop install nope-not-there >/dev/null 2>&1
check "an unknown launcher exits 1" 1 $status
session-env desktop install ../evil >/dev/null 2>&1
check "a path as a launcher name exits 2" 2 $status
session-env desktop install claude-desktop --group nope >/dev/null 2>&1
check "an unknown group exits 2" 2 $status
session-env desktop install claude-desktop --var 'bad name' >/dev/null 2>&1
check "an invalid variable name exits 2" 2 $status
session-env desktop frobnicate >/dev/null 2>&1
check "an unknown desktop command exits 2" 2 $status
check "nothing was written by the failed calls" false (test -e $dfile; and echo true; or echo false)

section "session-env: helper functions called directly"
set -l hsrc $tmp/h.desktop
printf '%s\n' '[Desktop Entry]' 'Exec=a %U' ' Name=keeps leading space' 'Exec=b' >$hsrc
set -l built (__session_env_desktop_build $hsrc '# M' V1 V2)
check "desktop_build: marker, vars, source, entry" '# M|# session-env-unset: V1 V2|# session-env-source: '$hsrc'|[Desktop Entry]|Exec=env -u V1 -u V2 a %U| Name=keeps leading space|Exec=env -u V1 -u V2 b' \
    (string join '|' -- $built)
set -gx XDG_DATA_HOME $tmp/hdata
check "__session_env_desktop status runs against the catalog" true \
    (__session_env_desktop $repo_root/data/session-env.tsv status | string match -q '*No managed*'; and echo true; or echo false)
set -gx PATH $bin $PATH
rm -f $calls
__session_env_apply_now literal:FOO=bar copy:BAZ=qux >/dev/null
check "__session_env_apply_now passes copy and literal values" 'systemctl --user set-environment FOO=bar BAZ=qux' \
    (string match 'systemctl --user set-environment*' <$calls)
set -gx PATH $saved_path

# ── First-run offer and setup ───────────────────────────────────────────
section "session-env: first-run offer"
set -l home $tmp/home
set -l cfg $tmp/cfg
mkdir -p $home $cfg/fish
ln -sfn $repo_root/data $cfg/fish/data
set -l fnpath "set -g fish_function_path $repo_root/functions \$__fish_data_dir/functions"

# _offer_run PRE-CODE...: source the conf.d component in a fresh interactive
# child with real (sandboxed) universal variables. Sets $offer_out.
function _offer_run --inherit-variable home --inherit-variable cfg --inherit-variable fnpath --inherit-variable repo_root
    set -g offer_out (env HOME=$home XDG_CONFIG_HOME=$cfg XDG_DATA_HOME=$home/data TERM=xterm \
        fish -i -c "$fnpath; source $repo_root/conf.d/__fish_config_op_registry.fish; $argv; source $repo_root/conf.d/session-env-offer.fish; set -q __fish_config_session_env_offered; and echo OFFERED=\$__fish_config_session_env_offered; or echo OFFERED=unset" 2>&1 | string collect)
end

_offer_run 'function __session_env_has_systemd; true; end'
check "the hint is printed on an interactive systemd start" true \
    (string match -q "*session-env setup*" -- $offer_out; and echo true; or echo false)
check "the hint is remembered" true (string match -q '*OFFERED=1*' -- $offer_out; and echo true; or echo false)
_offer_run 'function __session_env_has_systemd; true; end'
check "it is not repeated" false (string match -q "*session-env setup*" -- $offer_out; and echo true; or echo false)

command rm -f $cfg/fish/fish_variables
_offer_run 'function __session_env_has_systemd; false; end'
check "silent without systemd" false (string match -q "*session-env setup*" -- $offer_out; and echo true; or echo false)
check "and not recorded without systemd" true (string match -q '*OFFERED=unset*' -- $offer_out; and echo true; or echo false)

_offer_run 'function __session_env_has_systemd; true; end; mkdir -p $XDG_CONFIG_HOME/environment.d; touch $XDG_CONFIG_HOME/environment.d/fish-config.conf'
check "silent once the file exists" false (string match -q "*session-env setup*" -- $offer_out; and echo true; or echo false)
command rm -rf $cfg/environment.d

_offer_run 'function __session_env_has_systemd; true; end; set -g __fish_config_op_greeting off'
check "C6 disabled: silent" false (string match -q "*session-env setup*" -- $offer_out; and echo true; or echo false)

# Non-interactive shells: nothing at all.
set -l ni (env HOME=$home XDG_CONFIG_HOME=$cfg fish -c \
    "$fnpath; function __session_env_has_systemd; true; end; source $repo_root/conf.d/__fish_config_op_registry.fish; source $repo_root/conf.d/session-env-offer.fish" 2>&1 | string collect)
check "non-interactive shell prints nothing" "" "$ni"

section "session-env: setup and dismiss"
command rm -f $cfg/fish/fish_variables
set -l run_sess "env HOME=$home XDG_CONFIG_HOME=$cfg XDG_DATA_HOME=$home/data TERM=xterm fish -c"
# Without a terminal, setup never blocks and installs nothing.
set -l out (env HOME=$home XDG_CONFIG_HOME=$cfg fish -c "$fnpath; session-env setup" </dev/null 2>&1 | string collect)
check "setup without a terminal exits 0" 0 $pipestatus[1]
check "setup without a terminal installs nothing" false (test -e $cfg/environment.d/fish-config.conf; and echo true; or echo false)
check "setup without a terminal says how to install" true (string match -q '*session-env install*' -- $out; and echo true; or echo false)

env HOME=$home XDG_CONFIG_HOME=$cfg fish -c "$fnpath; session-env dismiss" >/dev/null 2>&1
check "dismiss exits 0" 0 $status
check "dismiss is remembered" "OFFERED=1" (env HOME=$home XDG_CONFIG_HOME=$cfg fish -c 'echo OFFERED=$__fish_config_session_env_offered')
check "dismiss installs nothing" false (test -e $cfg/environment.d/fish-config.conf; and echo true; or echo false)

if type -q python3
    # A pty harness: answers fish's terminal query (it would otherwise wait
    # ten seconds for it), types ANSWER at the prompt, prints the exit code.
    set -l pty_script '
import os, pty, select, signal, sys, time
answer = sys.argv[1]
argv = sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
out = b""
sent = False
da = 0
end = time.time() + 40
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 1)
    if not r:
        continue
    try:
        d = os.read(fd, 4096)
    except OSError:
        break
    if not d:
        break
    out += d
    if out.count(b"\x1b[c") > da:
        da = out.count(b"\x1b[c")
        os.write(fd, b"\x1b[?62c")
    if not sent and b"[y/N]" in out:
        os.write(fd, answer.encode() + b"\n")
        sent = True
try:
    os.kill(pid, signal.SIGKILL)
except OSError:
    pass
_, st = os.waitpid(pid, 0)
print(os.WEXITSTATUS(st) if os.WIFEXITED(st) else 99)
'
    command rm -f $cfg/fish/fish_variables
    set -l res (env HOME=$home XDG_CONFIG_HOME=$cfg XDG_DATA_HOME=$home/data TERM=xterm \
        python3 -I -c $pty_script n fish -c "$fnpath; session-env setup" 2>&1)
    check "answering no exits 0" 0 $res[1]
    check "answering no installs nothing" false (test -e $cfg/environment.d/fish-config.conf; and echo true; or echo false)
    check "answering no is remembered" "OFFERED=1" (env HOME=$home XDG_CONFIG_HOME=$cfg fish -c 'echo OFFERED=$__fish_config_session_env_offered')

    command rm -f $cfg/fish/fish_variables
    set res (env HOME=$home XDG_CONFIG_HOME=$cfg XDG_DATA_HOME=$home/data TERM=xterm \
        python3 -I -c $pty_script y fish -c "$fnpath; session-env setup" 2>&1)
    check "answering yes exits 0" 0 $res[1]
    check "answering yes installs the default group" "# groups: xdg" (string match '# groups:*' <$cfg/environment.d/fish-config.conf)
    check "answering yes is remembered" "OFFERED=1" (env HOME=$home XDG_CONFIG_HOME=$cfg fish -c 'echo OFFERED=$__fish_config_session_env_offered')
end

command rm -rf $tmp

report
