# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   logging/terminal-capture
#
# SYNOPSIS
#   __fish_config_sync_logging
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
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   __fish_config_sync_logging
function __fish_config_sync_logging --description 'Sync C5 logging state: sentinel file, paru/yay wrappers, and tmux pipe-pane'
    set -l config_home $XDG_CONFIG_HOME
    if test -z "$config_home"
        set config_home "$HOME/.config"
    end
    set -l sentinel "$config_home/fish/.logging_disabled"

    if __fish_config_op_enabled (status current-function)
        # Logging enabled: remove sentinel
        rm -f $sentinel

        # Restart tmux pipe-pane for the current pane if inside tmux
        _tmux_pipe_log
    else
        # Logging disabled: create sentinel
        mkdir -p (dirname $sentinel)
        touch $sentinel

        # Stop tmux pipe-pane for the current pane if inside tmux
        if set -q TMUX
            tmux pipe-pane 2>/dev/null
        end
    end

    # Delegate paru/yay wrapper (re)generation and removal to the canonical
    # generators. They resolve the real binary via __fish_real_command
    # (never /usr/bin-assumed) and independently gate on their own C2/C5
    # keys, so sourcing them here covers both the enabled-regenerate and
    # disabled-remove cases without duplicating that logic. Previously this
    # function carried its own inferior copy (tee instead of a PTY, no
    # progress-bar rendering, hard-coded /usr/bin/paru|yay), which fought
    # the canonical generator for the wrapper file on every version-marker
    # mismatch. See startup-latency-JOB-BRIEF-FINDINGS.md §2.
    #
    # Routed through _fish_source_scoped: both files `return` early on
    # several guard checks, and a sourced `return` exits the *calling*
    # function, which would otherwise abort this function and skip
    # whichever of paru/yay hadn't run yet.
    _fish_source_scoped "$__fish_config_dir/conf.d/paru-wrapper.fish"
    _fish_source_scoped "$__fish_config_dir/conf.d/yay-wrapper.fish"
end
