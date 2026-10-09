# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   overrides/prompt

#
#          ╭──────────────────────────────────────────────────────────╮
#          │                       Fish Theme                         │
#          ╰──────────────────────────────────────────────────────────╯
# Catppuccin Mocha

# Forcing theme colors and $FZF_DEFAULT_OPTS is opinionated (C3 overrides).
# The FZF variable is universal, so clean up our Catppuccin value if it
# lingers from a session where overrides were still enabled.
if not __fish_config_op_enabled (status basename)
    if set -q FZF_DEFAULT_OPTS; and string match -q '*#1E1E2E*' -- "$FZF_DEFAULT_OPTS"
        set --erase FZF_DEFAULT_OPTS
    end
    return
end

# Below the cleanup block on purpose: that branch erases a stale universal
# FZF_DEFAULT_OPTS and must keep running wherever it runs today. Everything
# past here is interactive-only.
status is-interactive; or return

#   ─────────────────────── Syntax highlighting theme ──────────────────────
# Saves the bundled themes/catppuccin-mocha.theme (fish's own Catppuccin
# Mocha) to universal variables once, rather than setting colors every
# session. `fish_config theme choose` lasts only for its session; a saved
# theme persists, and the user can replace it with `fish_config theme save`.
# The save waits for the first prompt: from fish 4.3 a theme with light and
# dark sections can only be saved once $fish_terminal_color_theme is known,
# which is not yet the case while conf.d runs. Older versions save the dark
# colors. A failed save is retried next session. Bump the value after
# changing the bundled theme to save it again.
set -l theme_rev catppuccin-mocha@1
if test "$__fish_config_theme_saved" != $theme_rev
    function __fish_config_save_theme --on-event fish_prompt -V theme_rev
        functions --erase __fish_config_save_theme
        # `theme save` asks before overwriting the current theme; answer it.
        if echo y | fish_config theme save (string split --fields 1 @ -- $theme_rev) >/dev/null 2>&1
            set --universal __fish_config_theme_saved $theme_rev
        end
    end
end

#   ─────────────────────────── FZF theme colors ───────────────────────────
set -Ux FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4"
