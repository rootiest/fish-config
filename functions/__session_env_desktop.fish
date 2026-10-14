# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   __fish_palette
#
# CLASSIFICATION
#   bypasses-shadow(grep,mkdir,mv,rm)
#
# SYNOPSIS
#   __session_env_desktop CATALOG install|uninstall|preview|status [ARGS...]
#
# DESCRIPTION
#   Backs "session-env desktop". Some variables session-env exports must be
#   kept out of specific desktop apps. The motivating case is the privacy
#   group: DO_NOT_TRACK and DISABLE_TELEMETRY switch off claude-code's
#   feature flags, so the Claude desktop app's launcher has to start with
#   them unset.
#
#   install copies the system launcher NAME.desktop into the user's own
#   applications directory ($XDG_DATA_HOME/applications, normally
#   ~/.local/share/applications) with every Exec= line prefixed by
#   "env -u VAR ...". The user-level copy takes precedence over the system
#   one (XDG desktop-entry lookup), so the system file is never edited. The
#   copy starts with a "Managed by fish-config's session-env" marker; only
#   files carrying it are ever rewritten or removed, so uninstall deletes
#   exactly what install added and a launcher you edited by hand is never
#   touched. status lists the managed copies and flags one whose system
#   launcher has changed since.
#
# ARGUMENTS
#   install NAME [--var VAR]... [--group GROUP]...
#                    Variables to unset: the given variables plus every
#                    variable of the given catalog groups (default: the
#                    privacy group)
#   uninstall NAME   Remove the managed copy
#   preview NAME     Print what install would write
#   status           List managed copies
#
# EXIT STATUS
#   0  Success
#   1  Launcher not found, refused to touch an unmanaged file, or write failure
#   2  Usage error or unknown group
#
# EXAMPLE
#   __session_env_desktop $__fish_config_dir/data/session-env.tsv install claude-desktop
function __session_env_desktop --description 'Manage user-level .desktop overrides that unset session-env variables'
    __fish_palette

    set -l catalog $argv[1]
    set -l sub $argv[2]
    set -l rest $argv[3..]

    set -l data_home $XDG_DATA_HOME
    test -n "$data_home"; or set data_home $HOME/.local/share
    set -l user_dir $data_home/applications
    set -l marker "# Managed by fish-config's session-env desktop"

    switch $sub
        case install uninstall preview status
        case '*'
            echo "$c_err""session-env desktop: unknown command '$sub'$c_reset" >&2
            echo "Run $c_cmd""session-env help$c_reset for usage." >&2
            return 2
    end

    argparse --name='session-env desktop' 'v/var=+' 'g/group=+' -- $rest
    or return 2
    set rest $argv

    if test $sub = status
        set -l found 0
        for f in $user_dir/*.desktop
            test -f $f; or continue
            string match -q -- "$marker*" (command head -n1 $f); or continue
            set found 1
            set -l unset (string replace -rf '^# session-env-unset: ' '' <$f | string split -n ' ')
            set -l src (string replace -rf '^# session-env-source: ' '' <$f)
            set -l note ''
            if not test -f "$src"
                set note " $c_warn(system launcher is gone)$c_reset"
            else if test "$(string collect <$f)" != "$(__session_env_desktop_build $src "$marker" $unset | string collect)"
                set note " $c_warn(system launcher changed; re-run install)$c_reset"
            end
            echo "$c_cmd"(path basename $f)"$c_reset$note"
            echo "  Unsets:  $unset"
            echo "  Source:  $src"
        end
        if test $found -eq 0
            echo "$c_dim""No managed .desktop overrides in $user_dir$c_reset"
        end
        return 0
    end

    if test (count $rest) -ne 1
        echo "$c_err""session-env desktop: $sub needs exactly one launcher name$c_reset" >&2
        echo "Run $c_cmd""session-env help$c_reset for usage." >&2
        return 2
    end
    set -l name (string replace -r '\.desktop$' '' -- $rest[1])
    # A bare launcher id only: never a path, so nothing outside the two
    # applications directories can be named.
    if not string match -qr '^[A-Za-z0-9][A-Za-z0-9._+-]*$' -- $name
        echo "$c_err""session-env desktop: invalid launcher name '$rest[1]'$c_reset" >&2
        return 2
    end
    set -l target $user_dir/$name.desktop

    if test $sub = uninstall
        if not test -e $target
            echo "$c_dim""→ Nothing to remove ($target does not exist)$c_reset"
            return 0
        end
        if not string match -q -- "$marker*" (command head -n1 $target)
            echo "$c_err""session-env desktop: $target is not managed by session-env; leaving it alone$c_reset" >&2
            return 1
        end
        command rm -f $target; or return 1
        echo "$c_ok""→ Removed $target$c_reset"
        echo "  $c_dim""The system launcher is used again.$c_reset"
        return 0
    end

    # install / preview: the variables to unset.
    set -l unset $_flag_var
    for v in $unset
        if not string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- $v
            echo "$c_err""session-env desktop: invalid variable name '$v'$c_reset" >&2
            return 2
        end
    end
    set -l groups $_flag_group
    set -q groups[1]; or set -q unset[1]; or set groups privacy
    if set -q groups[1]
        if not test -f $catalog
            echo "$c_err""session-env: catalog not found at $catalog$c_reset" >&2
            return 1
        end
        for g in $groups
            set -l hit 0
            for line in (string match -rv '^\s*(#|$)' <$catalog)
                set -l f (string split \t -- $line)
                test "$f[1]" = $g; or continue
                set hit 1
                contains -- $f[3] $unset; or set -a unset $f[3]
            end
            if test $hit -eq 0
                echo "$c_err""session-env desktop: unknown group '$g'$c_reset" >&2
                return 2
            end
        end
    end

    # The launcher to copy: the first system entry on the data path, never
    # the user's own directory.
    set -l dirs (string split : -- $XDG_DATA_DIRS)
    set -q dirs[1]; or set dirs /usr/local/share /usr/share
    set -l src ''
    for d in $dirs
        test -n "$d"; or continue
        test "$d/applications" = $user_dir; and continue
        if test -f $d/applications/$name.desktop
            set src $d/applications/$name.desktop
            break
        end
    end
    if test -z "$src"
        echo "$c_err""session-env desktop: no system launcher $name.desktop found on XDG_DATA_DIRS$c_reset" >&2
        return 1
    end
    if not command grep -qF '[Desktop Entry]' $src
        echo "$c_err""session-env desktop: $src is not a desktop entry$c_reset" >&2
        return 1
    end

    set -l built (__session_env_desktop_build $src "$marker" $unset)

    if test $sub = preview
        printf '%s\n' $built
        return 0
    end

    if test -e $target
        if not string match -q -- "$marker*" (command head -n1 $target)
            echo "$c_err""session-env desktop: $target exists and is not managed by session-env; refusing to overwrite it$c_reset" >&2
            echo "  Move it aside first if you want session-env to manage this launcher." >&2
            return 1
        end
    end
    if not command mkdir -p $user_dir
        echo "$c_err""session-env desktop: cannot create $user_dir$c_reset" >&2
        return 1
    end
    if not printf '%s\n' $built >$target.tmp; or not command mv -f $target.tmp $target
        command rm -f $target.tmp
        echo "$c_err""session-env desktop: failed to write $target$c_reset" >&2
        return 1
    end
    echo "$c_ok""→ Wrote $target$c_reset"
    echo "  $c_dim""Unsets: $unset. Undo with: session-env desktop uninstall $name$c_reset"
    return 0
end
