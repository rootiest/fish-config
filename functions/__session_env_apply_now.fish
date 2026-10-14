# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   __fish_palette, __session_env_expand, systemctl,
#   dbus-update-activation-environment
#
# SYNOPSIS
#   __session_env_apply_now KIND:NAME=VALUE...
#
# DESCRIPTION
#   The optional "apply now" of session-env: pushes variables into the
#   running systemd user manager (systemctl --user set-environment) and
#   the D-Bus activation environment (dbus-update-activation-environment),
#   so programs launched from the desktop afterwards see them without a
#   re-login. Already-running programs keep their environment.
#
#   Each argument is KIND:NAME=VALUE. KIND copy is fish's resolved value
#   and always applied, like a copied line in the managed file. KIND
#   literal is a catalog value, resolved against the manager's own
#   environment and skipped when the manager already has NAME, matching
#   the ${NAME:-value} fallback the file uses. Either command is used only
#   when installed; with neither, nothing is changed. Never run at shell
#   startup: session-env calls this only when asked with --now or apply.
#
# EXIT STATUS
#   0  Applied through at least one command (or nothing needed applying)
#   1  Neither systemctl nor dbus-update-activation-environment exists, or
#      a command failed
#
# EXAMPLE
#   __session_env_apply_now literal:DO_NOT_TRACK=1 copy:EDITOR=nvim
function __session_env_apply_now --description 'Push session-env variables into the running user session'
    __fish_palette

    set -l have_systemctl 0
    set -l have_dbus 0
    type -q systemctl; and set have_systemctl 1
    type -q dbus-update-activation-environment; and set have_dbus 1
    if test $have_systemctl -eq 0 -a $have_dbus -eq 0
        echo "$c_err""session-env: neither systemctl nor dbus-update-activation-environment is installed; nothing applied$c_reset" >&2
        return 1
    end

    # The manager's current environment is what ${NAME:-...} falls back to at
    # login. Without systemctl the best available stand-in is this shell's.
    set -l mgr
    if test $have_systemctl -eq 1
        set mgr (command systemctl --user show-environment 2>/dev/null)
    else
        set mgr (command printenv)
    end

    set -l pairs
    set -l kept
    for item in $argv
        set -l kind (string replace -r ':.*' '' -- $item)
        set -l rest (string replace -r '^[^:]*:' '' -- $item)
        set -l name (string replace -r '=.*' '' -- $rest)
        set -l raw (string replace -r '^[^=]*=' '' -- $rest)
        if test $kind = copy
            set -a pairs "$name=$raw"
            continue
        end
        set -l present 0
        for p in $mgr
            string match -qr -- "^$name=.+" $p; and set present 1
        end
        if test $present -eq 1
            set -a kept $name
            continue
        end
        set -a pairs "$name="(__session_env_expand $raw $mgr)
    end

    set -l failed 0
    if set -q pairs[1]
        if test $have_systemctl -eq 1
            command systemctl --user set-environment $pairs; or set failed 1
        end
        if test $have_dbus -eq 1
            command dbus-update-activation-environment $pairs; or set failed 1
        end
    end

    if test $failed -ne 0
        echo "$c_err""session-env: applying to the running session failed$c_reset" >&2
        return 1
    end
    echo "$c_ok→ Applied "(count $pairs)" variable(s) to the running user session$c_reset"
    echo "  $c_dim""Only programs started from now on see them.$c_reset"
    if set -q kept[1]
        echo "  $c_dim""Left alone (already set in the session): $kept$c_reset"
    end
    return 0
end
