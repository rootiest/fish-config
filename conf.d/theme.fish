# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
#          ╭──────────────────────────────────────────────────────────╮
#          │                       Fish Theme                         │
#          ╰──────────────────────────────────────────────────────────╯
# Catppuccin Mocha

# Forcing theme colors and $FZF_DEFAULT_OPTS is opinionated (C3 overrides).
# The FZF variable is universal, so clean up our Catppuccin value if it
# lingers from a session where overrides were still enabled.
if not __fish_config_op_enabled __fish_config_op_overrides
    if set -q FZF_DEFAULT_OPTS; and string match -q '*#1E1E2E*' -- "$FZF_DEFAULT_OPTS"
        set --erase FZF_DEFAULT_OPTS
    end
    return
end

#   ────────────────────── Syntax highlighting colors ──────────────────────
set --global fish_color_autosuggestion 6c7086
set --global fish_color_cancel f38ba8
set --global fish_color_command 89b4fa
set --global fish_color_comment 7f849c
set --global fish_color_cwd f9e2af
set --global fish_color_cwd_root red
set --global fish_color_end fab387
set --global fish_color_error f38ba8
set --global fish_color_escape eba0ac
set --global fish_color_gray 6c7086
set --global fish_color_history_current --bold
set --global fish_color_host 89b4fa
set --global fish_color_host_remote a6e3a1
set --global fish_color_keyword f38ba8
set --global fish_color_match F28779
set --global fish_color_normal cdd6f4
set --global fish_color_operator f5c2e7
set --global fish_color_option a6e3a1
set --global fish_color_param f2cdcd
set --global fish_color_quote a6e3a1
set --global fish_color_redirection f5c2e7
set --global fish_color_search_match --background=313244
set --global fish_color_selection --background=313244
set --global fish_color_status f38ba8
set --global fish_color_user 94e2d5
set --global fish_color_valid_path --underline
set --global fish_pager_color_background
set --global fish_pager_color_completion cdd6f4
set --global fish_pager_color_description 6c7086
set --global fish_pager_color_prefix f5c2e7
set --global fish_pager_color_progress 6c7086
set --global fish_pager_color_secondary_background
set --global fish_pager_color_secondary_completion
set --global fish_pager_color_secondary_description
set --global fish_pager_color_secondary_prefix
set --global fish_pager_color_selected_background
set --global fish_pager_color_selected_completion
set --global fish_pager_color_selected_description
set --global fish_pager_color_selected_prefix

#   ─────────────────────────── FZF theme colors ───────────────────────────
set -Ux FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4"
