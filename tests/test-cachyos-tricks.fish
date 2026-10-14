#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Issue #335: config.fish no longer re-sources conf.d/tricks.fish after the
# CachyOS distro config. That is only correct while every function and
# bang-bang binding tricks.fish defines comes out of the distro config
# unchanged, so this suite checks exactly that:
#
#   * the comparison itself, against synthetic distro configs (one that
#     agrees with tricks.fish, one that drifts), so it cannot silently pass;
#   * the real /usr/share/cachyos-fish-config/cachyos-config.fish, when this
#     machine has it (skipped elsewhere, e.g. in the CI container).
#
# A failure in the second part means the distro config changed: either
# match the definition in tricks.fish, or re-assert ours from functions/
# in config.fish's cachyos-tricks block (as ls, lt, cleanup and copy are).

source (realpath (dirname (status filename)))/lib.fish

set -g sandbox (mktemp -d)
command mkdir -p $sandbox/home $sandbox/xdgcfg $sandbox/cache

# Print every function conf.d/tricks.fish defines (fish_indent-normalized)
# and the bang-bang bindings, after sourcing tricks.fish and then each file
# in $argv. Runs in a clean child fish under the sandbox HOME, so the
# distro's ~/.fish_profile and `set -U` never touch the real user.
function tricks_state
    set -l script '
        set -p fish_function_path $argv[1]/functions
        source $argv[1]/conf.d/__fish_config_op_registry.fish
        set -l before (functions -an)
        source $argv[1]/conf.d/tricks.fish
        set -l names
        for f in (functions -an)
            contains -- $f $before; or set -a names $f
        end
        for f in $argv[2..]
            source $f
        end
        for f in $names
            echo "== $f"
            functions --no-details -- $f | fish_indent | string match -rv "^\\s*\$"
        end
        for m in default insert
            bind -M $m ! 2>&1
            bind -M $m \$ 2>&1
        end'
    command env -i HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/xdgcfg \
        XDG_CACHE_HOME=$sandbox/cache PATH=$PATH TERM=xterm \
        (status fish-path) --no-config -c $script $repo_root $argv 2>&1
end

set -g baseline (tricks_state | string collect)

section "cachyos tricks: comparison sanity"

check "baseline lists tricks functions" 1 (string match -q -- '*== psmem10*' $baseline; and echo 1)
check "baseline lists the bang-bang binding" 1 (string match -q -- '*__history_previous_command_arguments*' $baseline; and echo 1)

# Same definitions as tricks.fish, spelled differently (the real distro
# config uses two-space indents and `;`): must compare equal.
printf '%s\n' \
    "alias psmem='ps auxf | sort -nr -k 4'" \
    'function backup --argument filename' \
    '  cp $filename $filename.bak' \
    end >$sandbox/agrees.fish
check "agreeing distro config leaves the state unchanged" 1 \
    (test "$baseline" = (tricks_state $sandbox/agrees.fish | string collect); and echo 1)

printf '%s\n' "alias psmem='ps aux'" >$sandbox/drifts.fish
check "drifting function is detected" 1 \
    (test "$baseline" != (tricks_state $sandbox/drifts.fish | string collect); and echo 1)

printf '%s\n' 'bind ! true' >$sandbox/rebinds.fish
check "drifting binding is detected" 1 \
    (test "$baseline" != (tricks_state $sandbox/rebinds.fish | string collect); and echo 1)

section "cachyos tricks: live distro config"

set -l distro /usr/share/cachyos-fish-config/cachyos-config.fish
if not test -f $distro
    echo "  SKIP  no $distro on this machine"
else
    set -l got (tricks_state $distro | string collect)
    if test "$baseline" != "$got"
        diff (printf '%s\n' $baseline | psub) (printf '%s\n' $got | psub) | sed 's/^/        /'
    end
    check "distro config redefines nothing tricks.fish defines" 1 \
        (test "$baseline" = "$got"; and echo 1)
end

command rm -rf $sandbox
report
