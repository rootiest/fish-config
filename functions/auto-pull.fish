# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# COMPONENT
#   autoexec/sync
#
# SYNOPSIS
#   auto-pull [list]
#   auto-pull add [PATH]
#   auto-pull remove <NAME|PATH>
#   auto-pull status
#
# DESCRIPTION
#   Manages the auto-pull registry: the list of repositories that are
#   background fast-forwarded when you enter them (see conf.d/auto-pull.fish
#   and _auto_pull_sync). The fish-config repo is always covered as a baseline
#   and does not need to be added. The registry is a plain text file, one
#   absolute git-toplevel path per line, stored machine-locally at
#   $__fish_user_dots_path/auto-pull.list (defaults to
#   ~/.config/.user-dots/fish/auto-pull.list) and never committed.
#
#   Registry management works regardless of the C2 auto-execution guard; only
#   the background sync itself is gated by __fish_config_op_autoexec.
#
# ARGUMENTS
#   list               Show registered repos (default when no subcommand given)
#   add [PATH]         Register PATH's git root; defaults to the current repo
#   remove <NAME|PATH> Unregister by basename or exact path
#   status             Show enabled/disabled state, repo count, and registry path
#   -h, --help         Show this help message
#
# EXIT STATUS
#   0  Subcommand succeeded
#   1  Bad usage, target is not a git repo, or target not registered
#
# EXAMPLE
#   cd ~/src/qmk_firmware; and auto-pull add
#   auto-pull add ~/work/api
#   auto-pull list
#   auto-pull remove qmk_firmware
function auto-pull --description 'Manage the auto-pull repository registry'
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold white)
    set -l c_flag (set_color yellow)
    set -l c_ok (set_color green)
    set -l c_warn (set_color yellow)
    set -l c_err (set_color red)
    set -l c_dim (set_color brblack)
    set -l c_reset (set_color normal)

    set -q __fish_config_dir; or set -l __fish_config_dir $XDG_CONFIG_HOME/fish
    set -q __fish_user_dots_path; or set -l __fish_user_dots_path "$XDG_CONFIG_HOME/.user-dots/fish"
    set -l list "$__fish_user_dots_path/auto-pull.list"

    set -l cmd $argv[1]
    set -e argv[1]

    if test "$cmd" = -h; or test "$cmd" = --help; or contains -- -h $argv; or contains -- --help $argv
        echo "$c_head""Usage:$c_reset $c_cmd""auto-pull$c_reset $c_flag""[list | add | remove | status]$c_reset $c_dim""[PATH|NAME]$c_reset"
        echo
        echo "  Manage the registry of repos that are background fast-forwarded on entry."
        echo
        echo "$c_head""Subcommands:$c_reset"
        echo "  $c_flag""list$c_reset              Show registered repos (default)"
        echo "  $c_flag""add$c_reset $c_dim""[PATH]$c_reset        Register PATH's git root (default: current repo)"
        echo "  $c_flag""remove$c_reset $c_dim""<NAME|PATH>$c_reset  Unregister by basename or exact path"
        echo "  $c_flag""status$c_reset            Show enabled/disabled state and registry path"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset        Show this help message"
        return 0
    end

    switch "$cmd"
        case '' list
            echo "$c_head""Auto-pull registry:$c_reset"
            echo "  $c_dim$__fish_config_dir$c_reset $c_dim(fish-config, baseline)$c_reset"
            if test -r "$list"
                for l in (command cat "$list" 2>/dev/null)
                    test -n "$l"; or continue
                    echo "  $l $c_dim("(path basename "$l")")$c_reset"
                end
            end
            return 0

        case add
            set -l target $argv[1]
            test -n "$target"; or set target $PWD
            set -l root (command git -C "$target" rev-parse --show-toplevel 2>/dev/null)
            if test -z "$root"
                echo "$c_err""auto-pull: not a git repository: $target$c_reset" >&2
                return 1
            end
            if test "$root" = "$__fish_config_dir"
                echo "$c_warn""auto-pull: fish-config is always covered (baseline); nothing to add$c_reset"
                return 0
            end
            command mkdir -p (path dirname "$list")
            test -f "$list"; or command touch "$list"
            if contains -- "$root" (command cat "$list" 2>/dev/null)
                echo "$c_dim""auto-pull: already registered: $root$c_reset"
                return 0
            end
            echo "$root" >>"$list"
            echo "$c_ok""→ auto-pull added: $root$c_reset"
            return 0

        case remove rm
            set -l target $argv[1]
            if test -z "$target"
                echo "$c_err""auto-pull: usage: auto-pull remove <NAME|PATH>$c_reset" >&2
                return 1
            end
            if not test -r "$list"
                echo "$c_dim""auto-pull: registry is empty$c_reset"
                return 1
            end
            set -l kept
            set -l removed
            for l in (command cat "$list" 2>/dev/null)
                test -n "$l"; or continue
                if test "$l" = "$target"; or test (path basename "$l") = "$target"
                    set -a removed "$l"
                else
                    set -a kept "$l"
                end
            end
            if test -z "$removed"
                echo "$c_err""auto-pull: not registered: $target$c_reset" >&2
                return 1
            end
            if test -n "$kept"
                printf '%s\n' $kept >"$list"
            else
                printf '' >"$list"
            end
            echo "$c_warn""→ auto-pull removed: $removed$c_reset"
            return 0

        case status
            if __fish_config_op_enabled (status current-function)
                echo "$c_ok""auto-pull: ENABLED$c_reset $c_dim(C2 auto-execution on)$c_reset"
            else
                echo "$c_warn""auto-pull: DISABLED$c_reset $c_dim(via __fish_config_op_autoexec)$c_reset"
            end
            set -l repos
            test -r "$list"; and set repos (command cat "$list" 2>/dev/null | string match -rv '^\s*$')
            echo "  registered repos: "(count $repos)" $c_dim(+ fish-config baseline)$c_reset"
            echo "  list file: $c_dim$list$c_reset"
            return 0

        case '*'
            echo "$c_err""auto-pull: unknown subcommand: $cmd$c_reset" >&2
            echo "$c_dim""try: auto-pull --help$c_reset" >&2
            return 1
    end
end
