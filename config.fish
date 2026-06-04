# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │                    Fish Configuration                    │
#          ╰──────────────────────────────────────────────────────────╯

#   ──────────────────────── Source CachyOS configs ────────────────────────
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
    # Source our tricks over the cachyOS config
    test -f "$__fish_config_dir/conf.d/tricks.fish"
    and source "$__fish_config_dir/conf.d/tricks.fish"
    # CachyOS defines aliases for ls/lt/cleanup that shadow our function files.
    # Erase them and immediately source our versions.
    for _fname in ls lt cleanup
        functions --erase $_fname
        source "$__fish_config_dir/functions/$_fname.fish"
    end
    # CachyOS defines a broken copy command.
    # Override it with our working function.
    test -f "$__fish_config_dir/functions/copy.fish"
    and source "$__fish_config_dir/functions/copy.fish"
end
set --erase _fname

#   ───────────────────────────── XDG variables ────────────────────────────
# XDG Base Directory variables (standard practice)
set -gx XDG_CONFIG_HOME $HOME/.config # Sets default config dir to ~/.config
set -gx XDG_CACHE_HOME $HOME/.cache # Sets default cache dir to ~/.cache
set -gx XDG_DATA_HOME $HOME/.local/share # Sets default data dir to ~/.local/share
set -gx XDG_STATE_HOME $HOME/.local/state # Sets default state dir to ~/.local/state

# Attempt to keep various config/cache files out of the home directory root
set -gx RANDFILE "$XDG_STATE_HOME/rnd"
set -gx WGETRC "$XDG_CONFIG_HOME/wget/wgetrc"
set -gx WGET_HSTS_FILE "$XDG_CACHE_HOME/wget-hsts"
set -gx NPM_CONFIG_PREFIX "$XDG_DATA_HOME/npm-global"
set -gx NPM_CONFIG_USERCONFIG "$XDG_CONFIG_HOME/npm/npmrc"
set -gx ANDROID_USER_HOME "$XDG_DATA_HOME/android"
set -gx CARGO_HOME "$XDG_DATA_HOME/cargo"
set -gx RUSTUP_HOME "$XDG_DATA_HOME/rustup"
set -gx GOPATH "$XDG_DATA_HOME/go"
set -gx BUN_INSTALL "$XDG_DATA_HOME/bun"
set -gx GNUPGHOME "$XDG_CONFIG_HOME/gnupg"
set -gx WAKATIME_HOME "$XDG_CONFIG_HOME/wakatime"
set -gx HISTFILE "$XDG_STATE_HOME/bash_history"
set -gx EXINIT "set viminfofile=$XDG_STATE_HOME/vim/viminfo | source $MYVIMRC"
set -gx NVIDIA_SETTINGS_RW_CONFIG_FILE "$XDG_CONFIG_HOME/nvidia/settings"
set -gx CODEIUM_HOME "$XDG_CONFIG_HOME/codeium"
set -gx WORDLIST "$XDG_CONFIG_HOME/hunspell_en_US"

#   ───────────────────── Misc Configuration variables ─────────────────────
#   ─────────────────────────── Pager variables ────────────────────────────
if type -q ov
    set -gx PAGER ov
else if type -q less
    set -gx PAGER less
end

#   ─────────────────────────── Editor variables ───────────────────────────
#   Set Editor variables with fallback to vi if nvim isn't available. This ensures that
#   tools that rely on these variables (like git commit messages) will work out of the box,
#   while still preferring nvim if it's installed.
if type -q nvim
    set -gx NVIM_APPNAME nvim
    set -gx EDITOR (command -s nvim)
else
    set -gx EDITOR (command -s vi)
end
set -gx VISUAL $EDITOR
set -gx SUDO_EDITOR $EDITOR

#   ──────────────────────────── GPG variables ─────────────────────────────
#   Helps ensure that GPG can prompt for passphrases correctly when invoked from the terminal.
set -gx GPG_TTY (tty)

#   ────────────────────────── Scrollback History ──────────────────────────
#   Directory where scrollback history is saved into log files.
set -gx SCROLLBACK_HISTORY_DIR "$HOME/.terminal_history"
#   Maximum number of scrollback history files to keep
set -gx SCROLLBACK_HISTORY_MAX_FILES 100
# Wire up a clean exit function that won't fire on background subshells
if status is-interactive
    function exit --description 'Safe interactive exit'
        # If the smart_exit file exists in our function path, invoke it explicitly
        if functions -q smart_exit
            smart_exit $argv
        else
            # Absolute fallback to protect shell mechanics
            builtin exit $argv
        end
    end
end

#   ──────────────────────────── PATH variables ────────────────────────────
#   Adds common user bin directories to the PATH. The -mg --move option for cargo ensures that
#   the cargo bin directory is moved to the end of the PATH, which can help avoid conflicts
#   with system-installed Rust tools while still allowing user-installed cargo binaries to be found.
fish_add_path $HOME/.local/bin
fish_add_path $HOME/Applications
fish_add_path $HOME/scripts
fish_add_path -mg --move $CARGO_HOME/bin
fish_add_path $BUN_INSTALL/bin
fish_add_path $XDG_DATA_HOME/npm-global/bin
fish_add_path $HOME/.lmstudio/bin
fish_add_path $HOME/.resend/bin
fish_add_path $HOME/.fzf/bin

#   ───────────────────────── CDPATH projects dir ──────────────────────────
# Allows cd-ing to directories within $HOME/projects or $HOME without needing to specify the full path.
# For example, if you have a project at $HOME/projects/myproject,
# you can simply run 'cd myproject' from anywhere and it will take you there.
# 'cd' command prioritizes directories in CDPATH, so if you have a directory with
# the same name in both $HOME/projects and $HOME, it will take you to the one in $HOME/projects first.
# Additionally, directories inside the CWD will still take precedence over CDPATH,
# so if you have a directory named 'myproject' in the current directory,
# running 'cd myproject' will take you there instead of $HOME/projects/myproject.
set -gx CDPATH . $HOME/projects $HOME

#   ──────────────────────────── Bootstrap Fisher ──────────────────────────
if not type -q fisher
    echo "Fisher plugin manager not found."
    read -l -P "Install Fisher and plugins now? [Y/n] " _fisher_reply
    if test -z "$_fisher_reply" -o "$_fisher_reply" = Y -o "$_fisher_reply" = y
        echo "Installing Fisher..."
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher update
        fish_config theme choose "Catppuccin Mocha"
    else
        echo "Skipping Fisher install. Some features may be unavailable."
    end
    set --erase _fisher_reply
end

#   ─────────────────────── visual/interactive setup ───────────────────────
# Run only if we're in an interactive session (not a script or non-interactive shell)
if status is-interactive
    #   ────────────────────────────── Key bindings ────────────────────────────
    #   Helps ensure that key bindings are consistent with the Vi editing mode set below.
    #   This is optional but can improve the user experience for those who prefer Vi-style key bindings.
    set -g fish_key_bindings fish_vi_key_bindings

    #   ──────────────────────── Source FZF integration ────────────────────────
    #   Prefer fzf's own fish integration (fzf --fish, available since fzf 0.48)
    #   which is always version-matched to the installed binary. Fall back to our
    #   bundled integrations/fzf.fish for older builds.
    #   Run `fzf-update` to install/upgrade fzf from git HEAD.
    if type -q fzf
        set -l _fzf_minor (fzf --version | string match -r '^\d+\.(\d+)')[2]
        if test -n "$_fzf_minor" -a "$_fzf_minor" -ge 48
            fzf --fish | source
        else
            test -f "$__fish_config_dir/integrations/fzf.fish"
            and source "$__fish_config_dir/integrations/fzf.fish"
        end
    else
        #   conf.d/fzf.fish is managed by Fisher and may be restored on fisher
        #   update, so this is the reliable place to strip its bindings when
        #   fzf is not installed.
        functions -q _fzf_uninstall_bindings; and _fzf_uninstall_bindings
    end

    #   ──────────────────────────────── DirENV ────────────────────────────────
    # Tool to handle automatic environment loading in directories and their children
    # Use when children need to load venv as well.
    #
    # The Auto-Venv script above will ignore directories with a
    # .envrc file (direnv configuration) to prevent conflicts.
    type -q direnv; and direnv hook fish | source

    #   Helps ensure that Claude Code's terminal output is clean and doesn't have flickering issues.
    set -gx CLAUDE_CODE_NO_FLICKER 1

    #   ╭────────────────────────────── OVERRIDES ─────────────────────────────╮
    #   |       Run these last so they can override any previous settings.     |
    #   |    This is useful for machine-specific behavior or configurations.   |
    #   ╰────────────────────────────── OVERRIDES ─────────────────────────────╯
    #
    # Define user-dots path variable for a more legible secrets/local config.
    set -l dot_fish "$XDG_CONFIG_HOME/.user-dots/fish"
    #   ───────────────────────── Source user secrets ──────────────────────────
    #   Sources a secrets.fish file if it exists, which can be used to store
    #   sensitive environment variables and configurations that shouldn't be
    #   committed to version control.
    #   This allows you to keep things like API keys, database credentials,
    #   and other secrets out of your main config files and safely ignored by git.
    test -f "$dot_fish/secrets.fish"; and source "$dot_fish/secrets.fish"

    #   ─────────────────────── Source machine-local config ────────────────────
    #   Sources a local.fish file if it exists, which can be used for machine-specific
    #   variables and configurations that shouldn't be shared across machines.
    #   This allows you to have different settings on different machines without affecting
    #   your main config or secrets files. For example, you might want different PATH additions,
    #   aliases, or environment variables on your work laptop vs. your home desktop.
    test -f "$dot_fish/local.fish"; and source "$dot_fish/local.fish"
    #
    #    ╭──────────────────────────── END OVERRIDES ──────────────────────────╮
    #    |                        End of override section.                     |
    #    ╰──────────────────────────── END OVERRIDES ──────────────────────────╯

    # ─────────────────────────────────────────────────────────────────────────
    # Tools like starship, zoxide, etc. append init lines below this point via their
    # setup commands. We manage all integrations through conf.d/ instead, so we
    # return here to prevent injected lines from conflicting with that setup.
    #
    # This catches injections within the interactive block and
    # prevents them from conflicting with our conf.d/ setup.
    return # <-- Do not remove this line.
    # ─────────────────────────────────────────────────────────────────────────
end

# ─────────────────────────────────────────────────────────────────────────────
# Tools like starship, zoxide, etc. append init lines below this point via their
# setup commands. We manage all integrations through conf.d/ instead, so we
# return here to prevent injected lines from conflicting with that setup.
#
# This catches injections outside the interactive block and
# prevents them from conflicting with our conf.d/ setup.
return # <-- Do not remove this line.
# ─────────────────────────────────────────────────────────────────────────────
