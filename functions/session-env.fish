# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# CLASSIFICATION
#   bypasses-shadow(mkdir,mv,rm)
#
# SYNOPSIS
#   session-env [install [GROUP...] | preview [GROUP...] | uninstall | status | list] [-h]
#
# DESCRIPTION
#   Exports fish-config variables to the whole login session, not just fish.
#   Variables set in config.fish only reach processes started from fish;
#   anything launched from the desktop (IDEs, the Claude desktop app,
#   systemd user services) never sees them. install writes the selected
#   groups from data/session-env.tsv to
#   ~/.config/environment.d/10-fish-config.conf, which systemd applies to
#   the user session at the next login. uninstall removes that file.
#
#   With no groups, install uses the catalog's default groups (only xdg,
#   the XDG base directories). Each install replaces the whole file, so
#   name every group you want each time. Entries that copy a fish value
#   (value "-" in the catalog) write fish's resolved value, and are skipped
#   when fish does not export that variable. Every other entry falls back
#   to a value already present in the session, so it never overrides one
#   set elsewhere.
#
# ARGUMENTS
#   install [GROUP...]  Write the given groups (default groups when none)
#   preview [GROUP...]  Print what install would write, without writing it
#   uninstall           Remove the managed file
#   status              Show the managed file and the groups it holds
#   list                Show every group and variable in the catalog
#   -h, --help          Show this help
#
# EXIT STATUS
#   0  Success
#   1  Unknown subcommand or group, missing catalog, or a write failure
#
# EXAMPLE
#   session-env install
#   session-env install xdg xdg-tools editor
#   session-env preview xdg wayland
#   session-env uninstall
function session-env --description 'Export fish-config variables to the login session via environment.d'
    __fish_palette

    set -l cmd $argv[1]

    if test -z "$cmd"; or contains -- "$cmd" -h --help
        echo "$c_head""Usage:$c_reset $c_cmd""session-env$c_reset $c_flag""[install|preview|uninstall|status|list]$c_reset $c_flag""[GROUP...]$c_reset $c_flag""[-h]$c_reset"
        echo
        echo "  Export fish-config variables to the whole login session (environment.d)."
        echo
        echo "$c_head""Commands:$c_reset"
        echo "  $c_flag""install$c_reset [GROUP...]  Write the groups (default groups when none)"
        echo "  $c_flag""preview$c_reset [GROUP...]  Print what install would write"
        echo "  $c_flag""uninstall$c_reset           Remove the managed file"
        echo "  $c_flag""status$c_reset              Show the managed file and its groups"
        echo "  $c_flag""list$c_reset                Show every group and variable"
        echo "  $c_flag""-h$c_reset, $c_flag""--help$c_reset          Show this help message"
        return 0
    end

    set -l catalog $__fish_config_dir/data/session-env.tsv
    set -l config_home $XDG_CONFIG_HOME
    test -n "$config_home"; or set config_home $HOME/.config
    set -l file $config_home/environment.d/10-fish-config.conf

    switch $cmd
        case uninstall
            if test -f $file
                command rm -f $file; or return 1
                echo "$c_ok""→ Removed $file$c_reset"
                echo "  $c_dim""Takes effect at your next login.$c_reset"
            else
                echo "$c_dim""→ Nothing to remove ($file does not exist)$c_reset"
            end
            return 0

        case status
            if not test -f $file
                echo "$c_warn""Not installed$c_reset ($file does not exist)"
                return 0
            end
            set -l groups (string replace -rf '^# groups: ' '' <$file)
            set -l vars (string match -rv '^\s*(#|$)' <$file)
            echo "$c_head""Session environment$c_reset"
            echo "  File:      $file"
            echo "  Groups:    $groups"
            echo "  Variables: "(count $vars)
            echo "  $c_dim""Changes apply at login; run session-env preview to compare.$c_reset"
            return 0
    end

    if not test -f $catalog
        echo "$c_err""session-env: catalog not found at $catalog$c_reset" >&2
        return 1
    end

    # Parse the catalog into parallel lists, one element per variable.
    set -l groups
    set -l defaults
    set -l names
    set -l values
    set -l descs
    for line in (string match -rv '^\s*(#|$)' <$catalog)
        set -l f (string split \t -- $line)
        set -a groups $f[1]
        set -a defaults $f[2]
        set -a names $f[3]
        set -a values $f[4]
        set -a descs "$f[5]"
    end

    switch $cmd
        case list
            set -l installed
            test -f $file; and set installed (string replace -rf '^# groups: ' '' <$file | string split ' ')
            set -l seen
            for g in $groups
                contains -- $g $seen; and continue
                set -a seen $g
                set -l tags
                test "$defaults[(contains -i -- $g $groups)]" = 1; and set -a tags default
                contains -- $g $installed; and set -a tags installed
                echo
                echo "$c_head$g$c_reset $c_dim$tags$c_reset"
                for i in (seq (count $names))
                    test "$groups[$i]" = $g; or continue
                    set -l v $values[$i]
                    test "$v" = -; and set v "(copied from fish)"
                    printf '  %s%-40s%s %s\n' $c_cmd $names[$i] $c_reset $descs[$i]
                    printf '  %s%-40s %s%s\n' $c_dim '' $v $c_reset
                end
            end
            return 0

        case install preview
            set -l want $argv[2..]
            if not set -q want[1]
                for i in (seq (count $names))
                    if test "$defaults[$i]" = 1; and not contains -- $groups[$i] $want
                        set -a want $groups[$i]
                    end
                end
            end
            for g in $want
                if not contains -- $g $groups
                    echo "$c_err""session-env: unknown group '$g'$c_reset" >&2
                    echo "Run $c_cmd""session-env list$c_reset to see the groups." >&2
                    return 1
                end
            end

            set -l out "# Managed by fish-config's session-env; regenerated on install, do not edit." \
                "# groups: $want"
            for i in (seq (count $names))
                contains -- $groups[$i] $want; or continue
                set -l name $names[$i]
                set -l v $values[$i]
                if test "$v" = -
                    # Copy fish's exported value, quoted so environment.d
                    # keeps it literal: "$$" is its escape for a dollar.
                    set -l cur (command printenv $name)
                    if test (count $cur) -ne 1
                        echo "$c_warn""→ Skipped $name: fish does not export a single-line value$c_reset" >&2
                        continue
                    end
                    # It is already fish's resolved value, so no fallback.
                    set -a out "$name=\""(string replace -a '\\' '\\\\' -- $cur | string replace -a '"' '\\"' | string replace -a '$' '$$')'"'
                    continue
                end
                # Fall back to a value already in the session (quotes would
                # be kept literally inside ${...}, so literals stay unquoted).
                # PATH-style entries reference themselves and stay as written.
                if not string match -q "*\${$name}*" -- $v
                    set v "\${$name:-$v}"
                end
                set -a out "$name=$v"
            end

            if test $cmd = preview
                printf '%s\n' $out
                return 0
            end

            if not command mkdir -p (path dirname $file)
                echo "$c_err""session-env: cannot create "(path dirname $file)"$c_reset" >&2
                return 1
            end
            if not printf '%s\n' $out >$file.tmp; or not command mv -f $file.tmp $file
                command rm -f $file.tmp
                echo "$c_err""session-env: failed to write $file$c_reset" >&2
                return 1
            end
            echo "$c_ok""→ Wrote $file$c_reset ($want)"
            echo "  $c_dim""Takes effect at your next login.$c_reset"
            return 0

        case '*'
            echo "$c_err""session-env: unknown command '$cmd'$c_reset" >&2
            echo "Run $c_cmd""session-env --help$c_reset for usage." >&2
            return 1
    end
end
