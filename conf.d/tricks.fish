# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#           ────── Borrowed and modified from CachyOS config ─────────
#          ╭──────────────────────────────────────────────────────────╮
#          │       Provides PATH additions, bang-bang helpers,        │
#          │       system aliases, and history/backup utilities       │
#          ╰──────────────────────────────────────────────────────────╯

## Environment setup
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
    source ~/.fish_profile
end

# Append unique directories to $PATH (fish_add_path handles duplicates automatically)
fish_add_path ~/.local/bin
fish_add_path ~/Applications/depot_tools

# Expose user-local man pages and keep fish-config.1 symlink current
if not contains ~/.local/share/man $MANPATH
    set -gx MANPATH ~/.local/share/man $MANPATH
end
set -l _man1 ~/.local/share/man/man1
set -l _src ~/.config/fish/docs/fish-config.1
if test -f $_src; and not test -L $_man1/fish-config.1
    mkdir -p $_man1
    ln -sf $_src $_man1/fish-config.1
end

# Format man pages using bat (only if bat is installed)
# Overriding $MANPAGER is opinionated (C3 overrides)
if type -q bat; and __fish_config_op_enabled __fish_config_op_overrides
    set -gx MANROFFOPT -c
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

# Set settings for https://github.com/franciscolourenco/done
set -gx __done_min_cmd_duration 10000
set -gx __done_notification_urgency_level low

## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
# The bang-bang system is opinionated (C3 overrides) and is gated atomically
# here, in conf.d/abbr.fish, conf.d/puffer.fish, and functions/expand_*.fish.
if __fish_config_op_enabled __fish_config_op_overrides
    function __history_previous_command
        switch (commandline -t)
            case "!"
                commandline -t $history[1]
                commandline -f repaint
            case "*"
                commandline -i !
        end
    end

    function __history_previous_command_arguments
        switch (commandline -t)
            case "!"
                commandline -t ""
                commandline -f history-token-search-backward
            case "*"
                commandline -i '$'
        end
    end

    # Apply bang-bang key bindings based on current key binding mode
    if [ "$fish_key_bindings" = fish_vi_key_bindings ]
        bind -Minsert ! __history_previous_command
        bind -Minsert '$' __history_previous_command_arguments
    else
        bind ! __history_previous_command
        bind '$' __history_previous_command_arguments
    end
end

# Fish command history override to show timestamps
# Shadowing the history command is opinionated (C1 aliasing); when disabled,
# the function is never defined and fish's stock history behavior applies.
if __fish_config_op_enabled __fish_config_op_aliases
    function history
        builtin history --show-time='%F %T '
    end
end

# Quick file backup utility
function backup --argument filename
    cp $filename $filename.bak
end

# Memory monitoring helpers
function psmem
    ps auxf | sort -nr -k 4
end

function psmem10
    ps auxf | sort -nr -k 4 | head -10
end

## Useful aliases

# Navigation short-cuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Silent flag injection into POSIX tools is opinionated (C1 aliasing)
if __fish_config_op_enabled __fish_config_op_aliases
    # Tools & Core command color overrides
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'

    # Safety aliases (Confirmation before overwriting/deleting)
    alias cp="cp -i"
    alias mv="mv -i"

    # Force wget to resume partial downloads
    alias wget='wget -c '
end

# Archives and networking short-hands
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias tb='nc termbin.com 9999'

# System Logs
alias jctl="journalctl -p 3 -xb"
