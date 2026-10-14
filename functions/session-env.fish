# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# DEPENDENCIES
#   __session_env_apply_now, __session_env_desktop
#
# CLASSIFICATION
#   bypasses-shadow(mkdir,mv,rm)
#
# SYNOPSIS
#   session-env COMMAND [ARGS...]
#   session-env install [GROUP...] [--var NAME]... [--except NAME]... [--now]
#   session-env add|remove ITEM... [--now]
#   session-env sync [--now] | apply | preview [GROUP...] | uninstall
#   session-env status | list | setup | dismiss | help
#   session-env desktop install|uninstall|preview NAME | status
#
# DESCRIPTION
#   Exports fish-config variables to the whole login session, not just fish.
#   Variables set in config.fish only reach processes started from fish;
#   anything launched from the desktop (IDEs, the Claude desktop app,
#   systemd user services) never sees them. install writes the selected
#   variables from data/session-env.tsv to
#   ~/.config/environment.d/fish-config.conf, which systemd applies to
#   the user session at the next login. uninstall removes that file. The
#   name has no numeric prefix so it sorts after numbered files such as
#   99-environment.conf (/etc/environment, which may set an absolute PATH).
#
#   With no groups, install uses the catalog's default groups (only xdg,
#   the XDG base directories). Each install replaces the whole file, so
#   name every group you want each time. Entries that copy a fish value
#   (value "-" in the catalog) write fish's resolved value, and are skipped
#   when fish does not export that variable. Every other entry falls back
#   to a value already present in the session, so it never overrides one
#   set elsewhere.
#
#   Selection is per variable. A group is shorthand for all its variables;
#   --var adds one variable to an install and --except leaves one out.
#   add and remove change what is installed by variable or group and keep
#   the rest. The file records the choice in its header: "# groups:" names
#   the groups that have a selected variable, and a "# vars:" line (written
#   only when some group is partly selected) is the exact variable list.
#   status, list, sync and every later add or remove read the same header,
#   so the selection round-trips. A file with only "# groups:", as written
#   before per-variable selection, means every variable of those groups.
#
#   A copied value is a snapshot taken at install time. status compares the
#   file with what install would write now and lists every difference
#   (a copied value that changed, a variable fish stopped exporting, an
#   entry the catalog gained); sync rewrites the file from its own
#   selection to refresh it, without resetting to the default groups.
#
#   environment.d is read at login. With --now (or the apply command)
#   session-env also pushes the selection into the running user manager
#   (systemctl --user set-environment) and the D-Bus activation
#   environment (dbus-update-activation-environment), so programs started
#   afterwards see it without a re-login. Each is used only when
#   installed, nothing runs at shell startup, and programs already running
#   keep their environment. A catalog value is applied only when the
#   session does not already have the variable, like the file's fallback.
#
#   An interactive shell with no environment.d file yet is told once, at
#   startup, that setup exists (conf.d/session-env-offer.fish, part of the
#   C6 first-run greeting). setup asks whether to install the default
#   group, never blocks without a terminal, and records the answer;
#   dismiss records "no" without asking.
#
#   desktop manages user-level copies of .desktop launchers whose Exec
#   lines start with "env -u VAR ...", for apps that must not see some of
#   the exported variables. The motivating case is the privacy group:
#   DO_NOT_TRACK and DISABLE_TELEMETRY switch off claude-code's feature
#   flags, so the Claude desktop app's launcher needs them unset. Only
#   files in $XDG_DATA_HOME/applications (~/.local/share/applications) are
#   written, never the system copy, and each starts with a marker line so
#   uninstall removes exactly what install added and never a launcher you
#   edited yourself.
#
# ARGUMENTS
#   install [GROUP...]  Write the given groups (default groups when none)
#   --var NAME          install: include one more variable (repeatable)
#   --except NAME       install: leave a variable out (repeatable)
#   add ITEM...         Add variables or groups to the installed selection
#   remove ITEM...      Remove variables or groups from the installed selection
#   sync                Rewrite the file from its own selection
#   apply               Push the installed selection into the running session
#   --now               install, sync, add, remove: also apply immediately
#   preview [GROUP...]  Print what install would write, without writing it
#   uninstall           Remove the managed file
#   status              Show the file, its selection and whether it is stale
#   list                Show every group and variable, marking the selection
#   setup               Ask once whether to install the default group
#   dismiss             Record that setup is not wanted
#   desktop install NAME [--var VAR]... [--group GROUP]...
#                       Create the override (default: unset the privacy group)
#   desktop uninstall NAME   Remove the override
#   desktop preview NAME     Print the override without writing it
#   desktop status           List overrides this tool manages
#   help, -h, --help    Show this help
#
# EXIT STATUS
#   0  Success, or help was shown
#   1  Missing catalog, nothing installed, or a write or apply failure
#   2  Unknown command, group or variable, or a usage error
#
# EXAMPLE
#   session-env install
#   session-env install xdg xdg-tools editor
#   session-env install xdg privacy --except DISABLE_TELEMETRY
#   session-env add CARGO_HOME GOPATH
#   session-env remove telemetry
#   session-env status
#   session-env sync --now
#   session-env desktop install claude-desktop
#   session-env desktop uninstall claude-desktop
#
# NOTES
#   Known limits. environment.d applies at login only; --now reaches
#   programs started after it, not running ones. Hooks and MCP servers
#   that claude spawns do not get the privacy variables: the
#   CLAUDE_CODE_SHELL_PREFIX helper covers only the Bash tool, and putting
#   the variables in claude's own environment (settings.json env, or the
#   session) is what disables its feature flags. There is no central
#   setting for spawned hooks and MCP servers, so set them where they are
#   spawned: the "env" map of each stdio server in .mcp.json (or
#   claude mcp add --env NAME=value), and an "env NAME=value" prefix in a
#   hook's command string.
function session-env --description 'Export fish-config variables to the login session via environment.d'
    __fish_palette

    if not set -q argv[1]; or test "$argv[1]" = help; or __fish_help_requested $argv
        echo "$c_head""Usage:$c_reset $c_cmd""session-env$c_reset $c_flag""COMMAND$c_reset $c_flag""[ARGS...]$c_reset $c_flag""[-h]$c_reset"
        echo
        echo "  Export fish-config variables to the whole login session (environment.d)."
        echo
        echo "$c_head""Commands:$c_reset"
        echo "  $c_flag""install$c_reset [GROUP...]  Write the groups (default groups when none)"
        echo "                      $c_flag""--var$c_reset NAME      also include one variable"
        echo "                      $c_flag""--except$c_reset NAME   leave one variable out"
        echo "                      $c_flag""--now$c_reset           also apply to the running session"
        echo "  $c_flag""add$c_reset ITEM...         Add variables or groups to what is installed"
        echo "  $c_flag""remove$c_reset ITEM...      Remove variables or groups from what is installed"
        echo "  $c_flag""sync$c_reset                Rewrite the file from its own selection (refresh copied values)"
        echo "  $c_flag""apply$c_reset               Push the installed selection into the running session"
        echo "  $c_flag""preview$c_reset [GROUP...]  Print what install would write"
        echo "  $c_flag""uninstall$c_reset           Remove the managed file"
        echo "  $c_flag""status$c_reset              Show the file, its selection, and whether it is stale"
        echo "  $c_flag""list$c_reset                Show every group and variable"
        echo "  $c_flag""setup$c_reset               Guided first-run offer to install the default group"
        echo "  $c_flag""dismiss$c_reset             Stop offering setup"
        echo "  $c_flag""desktop$c_reset COMMAND     User-level .desktop overrides that unset variables:"
        echo "                      $c_flag""install$c_reset NAME [--var VAR]... [--group GROUP]..."
        echo "                      $c_flag""uninstall$c_reset NAME | $c_flag""preview$c_reset NAME | $c_flag""status$c_reset"
        echo "  $c_flag""help$c_reset, $c_flag""-h$c_reset, $c_flag""--help$c_reset    Show this help message"
        return 0
    end

    # -- ends option parsing: what follows is data, never a help request.
    # Only a leading -- is dropped here; a later one is left for argparse.
    set -l args $argv
    test "$args[1]" = --; and set -e args[1]
    set -l cmd $args[1]
    set -l rest $args[2..]

    set -l catalog $__fish_config_dir/data/session-env.tsv
    set -l config_home $XDG_CONFIG_HOME
    test -n "$config_home"; or set config_home $HOME/.config
    set -l file $config_home/environment.d/fish-config.conf

    # Selection flags, for the commands that build a selection. argparse
    # runs here, at function scope: inside a switch or if it would set its
    # _flag_* variables in that block only.
    set -l sel_cmd 0
    contains -- $cmd install preview sync add remove apply; and set sel_cmd 1
    set -l parse_args --
    test $sel_cmd -eq 1; and set parse_args -- $rest
    argparse --name=session-env n/now 'v/var=+' 'x/except=+' $parse_args
    or return 2
    if test $sel_cmd -eq 1
        set rest $argv
        if test $cmd = preview; and set -q _flag_now
            echo "$c_err""session-env: --now does not apply to preview$c_reset" >&2
            return 2
        end
        if contains -- $cmd sync apply
            if set -q _flag_var[1]; or set -q _flag_except[1]; or set -q rest[1]
                echo "$c_err""session-env: $cmd takes no selection; use install, add or remove$c_reset" >&2
                return 2
            end
        end
    end

    # ── Commands that need no catalog ────────────────────────────────────
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

        case dismiss
            set -U __fish_config_session_env_offered 1
            echo "$c_ok""→ Setup offer dismissed.$c_reset Run $c_cmd""session-env install$c_reset anytime."
            return 0

        case desktop
            __session_env_desktop $catalog $rest
            return $status
    end

    # ── The catalog, as parallel lists (one element per variable) ────────
    set -l groups
    set -l defaults
    set -l names
    set -l values
    set -l descs
    if test -f $catalog
        for line in (string match -rv '^\s*(#|$)' <$catalog)
            set -l f (string split \t -- $line)
            set -a groups $f[1]
            set -a defaults $f[2]
            set -a names $f[3]
            set -a values $f[4]
            set -a descs "$f[5]"
        end
    end

    if test $cmd = status; and not test -f $file
        echo "$c_warn""Not installed$c_reset ($file does not exist)"
        return 0
    end

    if not test -f $catalog
        # status can still describe the file; everything else needs the data.
        if test $cmd = status
            echo "$c_head""Session environment$c_reset"
            echo "  File:      $file"
            echo "  Groups:    "(string replace -rf '^# groups: ' '' <$file)
            echo "  $c_warn""Catalog not found at $catalog; selection and staleness not checked.$c_reset"
            return 0
        end
        echo "$c_err""session-env: catalog not found at $catalog$c_reset" >&2
        return 1
    end

    # ── What the installed file currently selects ────────────────────────
    # cur_sel is a 0/1 flag per catalog entry. A "# vars:" line is the exact
    # selection; a file with only "# groups:" (every file older than
    # per-variable selection) means every variable of those groups.
    set -l cur_groups
    set -l cur_vars
    set -l cur_unknown
    set -l cur_sel
    set -l has_vars_line 0
    if test -f $file
        set cur_groups (string replace -rf '^# groups: ?' '' <$file | string split -n ' ')
        if string match -rq '^# vars:' <$file
            set has_vars_line 1
            set cur_vars (string replace -rf '^# vars: ?' '' <$file | string split -n ' ')
        end
    end
    for i in (seq (count $names))
        set -l on 0
        if test $has_vars_line -eq 1
            contains -- $names[$i] $cur_vars; and set on 1
        else
            contains -- $groups[$i] $cur_groups; and set on 1
        end
        set -a cur_sel $on
    end
    for v in $cur_vars
        contains -- $v $names; or set -a cur_unknown $v
    end
    for g in $cur_groups
        contains -- $g $groups; or set -a cur_unknown $g
    end

    # ── Commands that only read the catalog ──────────────────────────────
    switch $cmd
        case list
            set -l have_file 0
            test -f $file; and set have_file 1
            set -l seen
            for g in $groups
                contains -- $g $seen; and continue
                set -a seen $g
                set -l tags
                # Hoisted: a command substitution inside a quoted index fails.
                set -l first (contains -i -- $g $groups)
                test "$defaults[$first]" = 1; and set -a tags default
                set -l total 0
                set -l on 0
                for i in (seq (count $names))
                    test "$groups[$i]" = $g; or continue
                    set total (math $total + 1)
                    test "$cur_sel[$i]" = 1; and set on (math $on + 1)
                end
                if test $on -eq $total -a $total -gt 0
                    set -a tags installed
                else if test $on -gt 0
                    set -a tags "partial $on/$total"
                end
                echo
                echo "$c_head$g$c_reset $c_dim$tags$c_reset"
                for i in (seq (count $names))
                    test "$groups[$i]" = $g; or continue
                    set -l v $values[$i]
                    test "$v" = -; and set v "(copied from fish)"
                    set -l box ''
                    set -l pad ''
                    if test $have_file -eq 1
                        set box '[ ] '
                        set pad '    '
                        test "$cur_sel[$i]" = 1; and set box '[x] '
                    end
                    printf '  %s%s%-40s%s %s\n' "$box" "$c_cmd" $names[$i] "$c_reset" "$descs[$i]"
                    printf '  %s%s%-40s %s%s\n' "$pad" "$c_dim" '' "$v" "$c_reset"
                end
            end
            return 0

        case setup
            if test -f $file
                echo "$c_dim""→ Already installed ($file); run session-env status.$c_reset"
                return 0
            end
            # Never block: without a terminal on stdin there is nobody to ask.
            if not isatty stdin; or not isatty stdout
                echo "Run $c_cmd""session-env install$c_reset to export the default group, or $c_cmd""session-env dismiss$c_reset to stop asking."
                return 0
            end
            set -l dgroups
            for i in (seq (count $names))
                test "$defaults[$i]" = 1; or continue
                contains -- $groups[$i] $dgroups; or set -a dgroups $groups[$i]
            end
            echo "$c_head""session-env$c_reset exports fish-config variables to your whole login session,"
            echo "so apps launched from the desktop see them too (not only fish)."
            echo "Default group: $c_cmd$dgroups$c_reset (see $c_cmd""session-env list$c_reset for the rest)."
            set -l ans
            read -l -P "Install it now? [y/N] " ans
            or set ans n
            set -U __fish_config_session_env_offered 1
            if string match -qri '^y(es)?$' -- (string trim -- $ans)
                session-env install
                return $status
            end
            echo "$c_dim""→ Not installing; you will not be asked again. Run session-env install anytime.$c_reset"
            return 0
    end

    # ── Build the selection this command asks for ────────────────────────
    set -l sel
    for i in (seq (count $names))
        set -a sel 0
    end

    switch $cmd
        case install preview
            set -l want $rest
            if not set -q want[1]; and not set -q _flag_var
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
                    return 2
                end
            end
            for i in (seq (count $names))
                contains -- $groups[$i] $want; and set sel[$i] 1
            end
            for v in $_flag_var
                set -l idx (contains -i -- $v $names)
                if not set -q idx[1]
                    echo "$c_err""session-env: unknown variable '$v'$c_reset" >&2
                    echo "Run $c_cmd""session-env list$c_reset to see the variables." >&2
                    return 2
                end
                set sel[$idx] 1
            end
            for v in $_flag_except
                set -l idx (contains -i -- $v $names)
                if not set -q idx[1]
                    echo "$c_err""session-env: unknown variable '$v'$c_reset" >&2
                    echo "Run $c_cmd""session-env list$c_reset to see the variables." >&2
                    return 2
                end
                set sel[$idx] 0
            end

        case add remove
            if not set -q rest[1]
                echo "$c_err""session-env: $cmd needs at least one variable or group$c_reset" >&2
                echo "Run $c_cmd""session-env help$c_reset for usage." >&2
                return 2
            end
            if test $cmd = remove; and not test -f $file
                echo "$c_err""session-env: nothing installed to remove from ($file does not exist)$c_reset" >&2
                return 1
            end
            set sel $cur_sel
            set -l flag 1
            test $cmd = remove; and set flag 0
            for item in $rest
                if contains -- $item $groups
                    for i in (seq (count $names))
                        test "$groups[$i]" = $item; and set sel[$i] $flag
                    end
                else
                    set -l idx (contains -i -- $item $names)
                    if not set -q idx[1]
                        echo "$c_err""session-env: unknown group or variable '$item'$c_reset" >&2
                        echo "Run $c_cmd""session-env list$c_reset to see them." >&2
                        return 2
                    end
                    set sel[$idx] $flag
                end
            end

        case sync apply status
            if not test -f $file
                echo "$c_err""session-env: nothing installed ($file does not exist); run session-env install$c_reset" >&2
                return 1
            end
            set sel $cur_sel

        case '*'
            echo "$c_err""session-env: unknown command '$cmd'$c_reset" >&2
            echo "Run $c_cmd""session-env help$c_reset for usage." >&2
            return 2
    end

    if not contains -- 1 $sel
        echo "$c_err""session-env: that leaves nothing selected; use session-env uninstall to remove the file$c_reset" >&2
        return 2
    end

    # ── Render the file ──────────────────────────────────────────────────
    # Groups with any selected variable, in catalog order; the file gets a
    # "# vars:" line only when some group is only partly selected.
    set -l out_groups
    set -l partial 0
    set -l sel_names
    for g in $groups
        contains -- $g $out_groups; and continue
        set -l total 0
        set -l on 0
        for i in (seq (count $names))
            test "$groups[$i]" = $g; or continue
            set total (math $total + 1)
            test "$sel[$i]" = 1; and set on (math $on + 1)
        end
        test $on -gt 0; and set -a out_groups $g
        test $on -gt 0 -a $on -lt $total; and set partial 1
    end
    for i in (seq (count $names))
        test "$sel[$i]" = 1; and set -a sel_names $names[$i]
    end

    set -l out "# Managed by fish-config's session-env; regenerated on install, do not edit." \
        "# groups: $out_groups"
    test $partial -eq 1; and set -a out "# vars: $sel_names"

    set -l ent_names
    set -l ent_lines
    set -l apply_items
    set -l skipped
    for i in (seq (count $names))
        test "$sel[$i]" = 1; or continue
        set -l name $names[$i]
        set -l v $values[$i]
        if test "$v" = -
            # Copy fish's exported value, quoted so environment.d
            # keeps it literal: "$$" is its escape for a dollar.
            set -l cur (command printenv $name)
            if test (count $cur) -ne 1
                set -a skipped $name
                continue
            end
            # It is already fish's resolved value, so no fallback.
            set -a ent_names $name
            set -a ent_lines "$name=\""(string replace -a '\\' '\\\\' -- $cur | string replace -a '"' '\\"' | string replace -a '$' '$$')'"'
            set -a apply_items "copy:$name=$cur"
            continue
        end
        set -a apply_items "literal:$name=$v"
        # Fall back to a value already in the session (quotes would
        # be kept literally inside ${...}, so literals stay unquoted).
        # PATH-style entries reference themselves and stay as written.
        if not string match -q "*\${$name}*" -- $v
            set v "\${$name:-$v}"
        end
        set -a ent_names $name
        set -a ent_lines "$name=$v"
    end

    if not contains -- $cmd status apply
        for name in $skipped
            echo "$c_warn""→ Skipped $name: fish does not export a single-line value$c_reset" >&2
        end
    end
    set -l expected $out $ent_lines

    switch $cmd
        case preview
            printf '%s\n' $expected
            return 0

        case apply
            __session_env_apply_now $apply_items
            return $status

        case status
            set -l file_entries (string match -rv '^\s*(#|$)' <$file)
            echo "$c_head""Session environment$c_reset"
            echo "  File:      $file"
            echo "  Groups:    $cur_groups"
            echo "  Variables: "(count $file_entries)
            if test $has_vars_line -eq 1
                echo "  Selection: individual variables (a \"# vars:\" line is present)"
            else
                echo "  Selection: whole groups"
            end
            if set -q cur_unknown[1]
                echo "  $c_warn""Not in the catalog (ignored): $cur_unknown$c_reset"
            end

            # Freshness: the file against what install would write now. Only
            # copied values can drift (fish's value is a snapshot); literals
            # change only when the catalog does.
            set -l diffs
            for entry in $ent_lines
                set -l n (string replace -r '=.*' '' -- $entry)
                set -l got (string match -r -- "^$n=.*" $file_entries)
                if not set -q got[1]
                    set -a diffs "  $n: missing from the file"
                else if test "$got[1]" != "$entry"
                    set -a diffs "  $n: file has "(string replace "$n=" '' -- $got[1])", fish now has "(string replace "$n=" '' -- $entry)
                end
            end
            for n in $skipped
                set -l got (string match -r -- "^$n=.*" $file_entries)
                set -q got[1]; and set -a diffs "  $n: in the file, but fish no longer exports a value"
            end
            for entry in $file_entries
                set -l n (string replace -r '=.*' '' -- $entry)
                contains -- $n $ent_names $skipped; and continue
                set -a diffs "  $n: in the file but not in the selection"
            end
            if set -q diffs[1]
                echo "  $c_warn""Stale:     "(count $diffs)" difference(s) from what install would write now$c_reset"
                printf '%s\n' $diffs
                echo "  $c_dim""Run session-env sync to refresh; changes apply at login.$c_reset"
            else
                echo "  Freshness: up to date"
                echo "  $c_dim""Changes apply at login; session-env apply pushes them into the running session.$c_reset"
            end
            return 0
    end

    # install, sync, add, remove: write the file.
    if not command mkdir -p (path dirname $file)
        echo "$c_err""session-env: cannot create "(path dirname $file)"$c_reset" >&2
        return 1
    end
    if not printf '%s\n' $expected >$file.tmp; or not command mv -f $file.tmp $file
        command rm -f $file.tmp
        echo "$c_err""session-env: failed to write $file$c_reset" >&2
        return 1
    end
    echo "$c_ok""→ Wrote $file$c_reset ($out_groups)"
    test $partial -eq 1; and echo "  $c_dim"(count $sel_names)" individually selected variable(s).$c_reset"
    if set -q _flag_now
        __session_env_apply_now $apply_items
        return $status
    end
    echo "  $c_dim""Takes effect at your next login; add --now to apply it to the running session too.$c_reset"
    return 0
end
