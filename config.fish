# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │                    Fish Configuration                    │
#          ╰──────────────────────────────────────────────────────────╯

#   ──────────────────────── Source CachyOS configs ────────────────────────
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
    # CachyOS defines aliases for ls/lt/cleanup that shadow our function files.
    # Erase them and immediately source our versions.
    for _fname in ls lt cleanup
        functions --erase $_fname
        source $__fish_config_dir/functions/$_fname.fish
    end
end
set --erase _fname

#   ───────────────────────── Source user secrets ──────────────────────────
if test -f $HOME/.config/.user-dots/fish/secrets.fish
    source $HOME/.config/.user-dots/fish/secrets.fish
end

#   ─────────────────────── Source machine-local config ─────────────────────
if test -f $HOME/.config/.user-dots/fish/local.fish
    source $HOME/.config/.user-dots/fish/local.fish
end

#   ──────────────────────────── PATH variables ────────────────────────────
fish_add_path ~/Applications
fish_add_path ~/scripts
fish_add_path -mg --move ~/.cargo/bin
fish_add_path ~/.npm-global/bin
fish_add_path ~/.lmstudio/bin

#   ─────────────────────────── Editor variables ───────────────────────────
if command -v nvim >/dev/null
    set -gx EDITOR (command -s nvim)
else
    set -gx EDITOR (command -s vi)
end
set -gx VISUAL $EDITOR
set -gx SUDO_EDITOR $EDITOR

#   ──────────────────────────── GPG variables ─────────────────────────────
set -gx GPG_TTY (tty)

#   ────────────────────────────── Key bindings ────────────────────────────
set -g fish_key_bindings fish_vi_key_bindings

#   ──────────────────────── Source FZF integration ────────────────────────
source ~/.config/fish/integrations/fzf.fish
# Configure FZF theme
set -Ux FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4"

#   ──────────────────────────────── DirENV ────────────────────────────────
# Tool to handle automatic environment loading in directories and their children
# Use when children need to load venv as well.
#
# The Auto-Venv script above will ignore directories with a
# .envrc file (direnv configuration) to prevent conflicts.
direnv hook fish | source

#   ────────────────────────────── Auto-Venv ───────────────────────────────
# Auto-activate Python venv on directory change
function __auto_source_fallback_venv --on-variable PWD
    status --is-command-substitution; and return

    # 1. Skip if direnv is already managing this directory
    if set -q DIRENV_DIR; or test -e ".envrc"
        return
    end

    # 2. If we are already in a venv, check if we've left its tree
    if set -q VIRTUAL_ENV
        # Check if the current PWD is still within the directory that owns the venv
        # (Assuming the venv is at the root of the project)
        set -l venv_root (string replace -r '/.venv$' '' $VIRTUAL_ENV)
        if not string match -q "$venv_root*" "$PWD"
            type -q deactivate; and deactivate
        end
        return
    end

    # 3. Only source the venv if we aren't already in one
    if test -e ".venv/bin/activate.fish"
        source .venv/bin/activate.fish
    end
end

#   ──────────────────── Docker Contexts for LazyDocker ────────────────────
function ld --description 'Run lazydocker on the current Docker context'
    # Fetch the host endpoint of the currently active Docker context
    set -l current_host (docker context inspect --format '{{.Endpoints.docker.Host}}')

    # Run lazydocker with the DOCKER_HOST variable set for this command only
    env DOCKER_HOST=$current_host lazydocker
end

#   ────────────────────── Claude Code Env Variables ───────────────────────
set -gx CLAUDE_CODE_NO_FLICKER 1

#   ───────────────────── Directory shortcut variables ─────────────────────
set -U cdp ~/projects

#   ───────────────────────── CDPATH projects dir ──────────────────────────
# Allows cd-ing to projects automatically from anywhere
set -U CDPATH . ~/projects ~

#   ─────────────────────────── Starship prompt ────────────────────────────
# STARSHIP_START
starship init fish | source
# STARSHIP_END
