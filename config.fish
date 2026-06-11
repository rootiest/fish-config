# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │                    Fish Configuration                    │
#          ╰──────────────────────────────────────────────────────────╯

#   ───────────────────── Opinionated component guards ─────────────────────
# Opinionated components (AGENTS.md Task #3) are wrapped in
# __fish_config_op_enabled <category> guards throughout this file and conf.d/.
# The helper always evaluates the master switch __fish_config_opinionated
# first (falsy disables everything), then the per-category opt-out variable:
#   __fish_config_op_aliases       C1 — command shadows / flag injection
#   __fish_config_op_autoexec      C2 — startup side-effects
#   __fish_config_op_overrides     C3 — key bindings, env, prompt overrides
#   __fish_config_op_integrations  C4 — terminal/tool coupling
#   __fish_config_op_logging       C5 — scrollback capture / AUR log wrappers
#   __fish_config_op_greeting      C6 — per-session greeting / first-run welcome
# Example: set -U __fish_config_op_aliases off   (erase to re-enable)

#   ──────────────────────── Source CachyOS configs ────────────────────────
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
    # Surgically overriding the distro config is opinionated (C3 overrides):
    # skip it entirely when overrides are disabled, keeping CachyOS defaults.
    if __fish_config_op_enabled __fish_config_op_overrides
        # Source our tricks over the cachyOS config
        test -f "$__fish_config_dir/conf.d/tricks.fish"
        and source "$__fish_config_dir/conf.d/tricks.fish"
        # Erase CachyOS aliases/functions that shadow our versions, then
        # re-source our versions since functions --erase removes autoload entries.
        for _fname in ls lt cleanup copy
            functions --erase $_fname
            source "$__fish_config_dir/functions/$_fname.fish"
        end
    end

    # The distro config ships opinionated pieces of its own (it is the origin
    # of tricks.fish); strip them when the matching category is disabled so
    # the guards hold on CachyOS systems too.
    if not __fish_config_op_enabled __fish_config_op_aliases
        for _fname in grep fgrep egrep dir vdir wget
            functions -q $_fname; and functions --erase $_fname
        end
        # Restore fish's stock versions where they exist (erasing alone would
        # also block autoloading the stock function).
        for _fname in history ls
            functions -q $_fname; and functions --erase $_fname
            test -f $__fish_data_dir/functions/$_fname.fish
            and source $__fish_data_dir/functions/$_fname.fish
        end
    end
    if not __fish_config_op_enabled __fish_config_op_overrides
        for _fname in __history_previous_command __history_previous_command_arguments
            functions -q $_fname; and functions --erase $_fname
        end
        bind --erase ! 2>/dev/null
        bind --erase '$' 2>/dev/null
        bind -M insert --erase ! 2>/dev/null
        bind -M insert --erase '$' 2>/dev/null
    end
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

#   ─────────────────────────── Pager variables ────────────────────────────
# Overriding $PAGER is opinionated (C3 overrides)
if __fish_config_op_enabled __fish_config_op_overrides
    if type -q ov
        set -gx PAGER ov
    else if type -q less
        set -gx PAGER less
    end
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
# Replacing the exit builtin is opinionated (C3 overrides); smart_exit also
# guards itself so a live toggle takes effect without restarting the shell.
if status is-interactive; and __fish_config_op_enabled __fish_config_op_overrides
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
fish_add_path $HOME/.local/bin               # Standard user-local executables (XDG spec)
fish_add_path $HOME/.local/share/../bin      # Alternative/legacy path for local user binaries
fish_add_path $HOME/Applications             # User-installed applications and standalone apps
fish_add_path $HOME/scripts                  # Custom personal shell scripts and automation
fish_add_path -mga $CARGO_HOME/bin           # Rust binaries and tools installed via Cargo
fish_add_path $BUN_INSTALL/bin               # Bun runtime executables and globally installed packages
fish_add_path $XDG_DATA_HOME/npm-global/bin  # Global Node.js/npm packages (XDG compliant location)
fish_add_path $HOME/.lmstudio/bin            # LM Studio CLI tools for local LLM management
fish_add_path $HOME/.resend/bin              # Resend email service CLI tools
fish_add_path $HOME/.fzf/bin                 # Fuzzy Finder (fzf) core binary and helper scripts

#   ───────────────────────── CDPATH projects dir ──────────────────────────
# Allows cd-ing to directories within $HOME/projects or $HOME without needing to specify the full path.
# For example, if you have a project at $HOME/projects/myproject,
# you can simply run 'cd myproject' from anywhere and it will take you there.
# 'cd' command prioritizes directories in CDPATH, so if you have a directory with
# the same name in both $HOME/projects and $HOME, it will take you to the one in $HOME/projects first.
# Additionally, directories inside the CWD will still take precedence over CDPATH,
# so if you have a directory named 'myproject' in the current directory,
# running 'cd myproject' will take you there instead of $HOME/projects/myproject.
# CDPATH injection is opinionated (C3 overrides)
if __fish_config_op_enabled __fish_config_op_overrides
    set -gx CDPATH . $HOME/projects $HOME
end

#   ──────────────────────────── Bootstrap Fisher ──────────────────────────
#   Fisher is bootstrapped automatically on first run via conf.d/first_run.fish

#   ─────────────────────── Visual/Interactive setup ───────────────────────
# Run only if we're in an interactive session (not a script or non-interactive shell)
if status is-interactive
    #   ────────────────────────────── Key bindings ────────────────────────────
    #   Helps ensure that key bindings are consistent with the Vi editing mode set below.
    #   This is optional but can improve the user experience for those who prefer Vi-style key bindings.
    #   Global Vi mode is opinionated (C3 overrides); without it fish keeps its
    #   default Emacs-style bindings.
    if __fish_config_op_enabled __fish_config_op_overrides
        set -g fish_key_bindings fish_vi_key_bindings
    end

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
    #   │        Run these last so they can override any previous settings.    │
    #   │    This is useful for machine-specific behavior or configurations.   │
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

    #   ─────────────────── C6: Greeting & First-Run UI override ───────────────
    # When the greeting category is disabled, stamp out any fish_greeting
    # function that distro configs set (e.g., CachyOS defines it as fastfetch).
    # This runs last inside the interactive block so our empty definition wins
    # over whatever cachyos-config.fish or vendor conf.d installed.
    if not __fish_config_op_enabled __fish_config_op_greeting
        function fish_greeting
        end
    end
    #
    #    ╭──────────────────────────── END OVERRIDES ──────────────────────────╮
    #    │                        End of override section.                     │
    #    ╰──────────────────────────── END OVERRIDES ──────────────────────────╯
end

return # <-- Do not remove this line.
#  ╭──────────────────────────────── !!!NOTE!!! ───────────────────────────────╮
#  │    Tools like starship, zoxide, etc. append init lines below this point   │
#  │     via their setup commands. We manage these integrations through        │
#  │  conf.d/ instead, so we return here to prevent duplicate or conflicting   │
#  │                         inits from being executed.                        │
#  │                                                                           │
#  │            If a tool's shell integration appears to do nothing,           │
#  │         check whether its setup command appended an init line here,       │
#  │ then create a conf.d/<tool>.fish instead and place the init in that file. │
#  ╰───────────────────────────────────────────────────────────────────────────╯
