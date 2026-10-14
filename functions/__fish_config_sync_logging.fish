# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   logging/terminal-capture
#
# CLASSIFICATION
#   self-limiting(rm,mkdir)
#
# SYNOPSIS
#   __fish_config_sync_logging [--startup]
#
# DESCRIPTION
#   Synchronises C5 logging state: creates or removes the Kitty sentinel
#   file ($XDG_CONFIG_HOME/fish/.logging_disabled), generates or removes the
#   paru/yay AUR-helper log wrappers, and starts or stops tmux pipe-pane
#   capture for the current pane — all based on the combined value of
#   __fish_config_opinionated (master) and __fish_config_op_logging (C5).
#   Called by --on-variable event handlers whenever either variable changes.
#   Safe to call at any time; wrapper removal only affects files bearing
#   the generated version-marker comment.
#
#   The sentinel is only touched when its state has to change: an existing
#   sentinel is not re-created, a missing one is not re-removed, and the
#   common already-in-sync start therefore forks nothing for it.
#
# ARGUMENTS
#   --startup  Skip the paru/yay wrapper delegation. Used by
#              conf.d/logging-events.fish, which runs just before fish
#              sources conf.d/pkg-wrappers.fish itself; delegating here as
#              well would execute that file twice per start. Every later
#              call (variable-change handlers, manual) omits it.
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   __fish_config_sync_logging
function __fish_config_sync_logging --description 'Sync C5 logging state: sentinel file, paru/yay wrappers, and tmux pipe-pane'
    set -l startup 0
    contains -- --startup $argv; and set startup 1

    set -l config_home $XDG_CONFIG_HOME
    if test -z "$config_home"
        set config_home "$HOME/.config"
    end
    set -l sentinel "$config_home/fish/.logging_disabled"

    if __fish_config_op_enabled (status current-function)
        # Logging enabled: remove sentinel (only when there is one to remove)
        if test -e $sentinel -o -L $sentinel
            rm -f $sentinel
        end

        # Restart tmux pipe-pane for the current pane if inside tmux
        _tmux_pipe_log
    else
        # Logging disabled: create sentinel. Skipped when it already exists:
        # its directory is then known to exist and nothing reads its mtime
        # (the Kitty watcher only tests for presence), so the default
        # already-in-sync start spawns neither mkdir nor touch.
        if not test -e $sentinel
            mkdir -p (path dirname $sentinel)
            touch $sentinel
        end

        # Stop tmux pipe-pane for the current pane if inside tmux
        if set -q TMUX
            tmux pipe-pane 2>/dev/null
        end
    end

    # Delegate paru/yay wrapper (re)generation and removal to the canonical
    # generator. It resolves the real binary via __fish_real_command
    # (never /usr/bin-assumed) and gates each wrapper on its own C2/C5
    # keys, so sourcing them here covers both the enabled-regenerate and
    # disabled-remove cases without duplicating that logic. Previously this
    # function carried its own inferior copy (tee instead of a PTY, no
    # progress-bar rendering, hard-coded /usr/bin/paru|yay), which fought
    # the canonical generator for the wrapper file on every version-marker
    # mismatch.
    #
    # Routed through _fish_source_scoped: the file `return`s early in a
    # non-interactive shell, and a sourced `return` exits the *calling*
    # function, which would otherwise abort this function.
    #
    # Skipped on the --startup call: fish sources pkg-wrappers.fish from
    # conf.d right after logging-events.fish anyway.
    if test $startup -eq 0
        _fish_source_scoped "$__fish_config_dir/conf.d/pkg-wrappers.fish"
    end

    # The sourced file returns early (status 1) in a non-interactive shell;
    # that is not a failure of this function.
    return 0
end
