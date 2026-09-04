# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_subcats <category_variable>
#
# DESCRIPTION
#   Prints the sub-category rows for one C1-C6 category, one per line as
#   "<slug>\t<label>\t<description>". This is a fish-native copy of the
#   taxonomy authored in docs/manual/08-components-reference/*.md (Task 9)
#   -- kept here as a static table rather than parsed from markdown at
#   draw time, since config-settings redraws on every keypress and every
#   terminal resize.
#
# ARGUMENTS
#   category_variable  One of the six __fish_config_op_<category> names
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   Tab-separated "<slug>\t<label>\t<description>" rows, one per line
#
# EXAMPLE
#   __config_settings_subcats __fish_config_op_aliases
function __config_settings_subcats --description 'List the sub-categories for one opinionated-component category'
    switch $argv[1]
        case __fish_config_op_aliases
            printf '%s\t%s\t%s\n' \
                filesystem Filesystem "ls, cat, cd, du, mkdir, rm, mv, zoxide" \
                search Search "rg" \
                network Network "ping, ssh, yt-dlp" \
                monitor Monitor "top" \
                shell-tools Shell-tools "bash, less, help" \
                dev-tools Dev-tools "claude, edit, agy"
        case __fish_config_op_autoexec
            printf '%s\t%s\t%s\n' \
                plugin-management Plugins "Fisher bootstrap" \
                pkg-wrappers Pkg-wrappers "paru/yay wrapper generation" \
                venv Venv "Python auto-activation" \
                telemetry Telemetry "WakaTime hook bootstrap" \
                sync Sync "auto-pull, user-dots symlink"
        case __fish_config_op_overrides
            printf '%s\t%s\t%s\n' \
                key-bindings Key-bindings "vi-mode, autopair, puffer, bang-bang" \
                environment Environment "PATH, PAGER, EDITOR, CDPATH" \
                prompt Prompt "Starship, right prompt, theme + FZF colors" \
                privacy Privacy "DO_NOT_TRACK, DISABLE_TELEMETRY"
        case __fish_config_op_integrations
            printf '%s\t%s\t%s\n' \
                terminal-abbrs Term-abbrs "Kitty/WezTerm abbreviations" \
                window-mgmt Window-mgmt "spwin, tab, split" \
                notifications Notifications "done, WakaTime hook" \
                history-logs History-logs "hist, logs" \
                pkg-upgrade Pkg-upgrade "upgrade"
        case __fish_config_op_logging
            printf '%s\t%s\t%s\n' \
                terminal-capture Term-capture "Kitty watcher, smart_exit scrollback" \
                multiplexer-capture Multiplexer "tmux, zellij" \
                pkg-logs Pkg-logs "paru/yay AUR log wrappers"
        case __fish_config_op_greeting
            printf '%s\t%s\t%s\n' \
                first-run First-run "welcome banner" \
                greeting-message Greeting "fish_greeting override"
    end
end
