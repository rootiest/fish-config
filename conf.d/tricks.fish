# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#           ────── Borrowed and modified from CachyOS config ─────────
#          ╭──────────────────────────────────────────────────────────╮
#          │       Provides PATH additions, bang-bang helpers,        │
#          │       system aliases, and history/backup utilities       │
#          ╰──────────────────────────────────────────────────────────╯

# COMPONENT
#   site aliases-tricks: aliases/filesystem
#   site tricks-manpager: overrides/environment
#   site tricks-bang: overrides/key-bindings

## Environment setup
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
    source ~/.fish_profile
end

# Append unique directories to $PATH (fish_add_path handles duplicates automatically)
fish_add_path ~/.local/bin
fish_add_path ~/Applications/depot_tools

# Expose user-local man pages
if not contains ~/.local/share/man $MANPATH
    set -gx MANPATH ~/.local/share/man $MANPATH
end

# Format man pages using bat (only if bat is installed)
# Overriding $MANPAGER is opinionated (C3 overrides)
if type -q bat; and __fish_config_op_enabled (status basename) tricks-manpager
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
if __fish_config_op_enabled (status basename) tricks-bang
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
        # @category History Expansion
        # @name !!
        # @desc Expand to the previous command
        bind -Minsert ! __history_previous_command
        # @category History Expansion
        # @name !$
        # @desc Expand to the last argument of the previous command
        bind -Minsert '$' __history_previous_command_arguments
    else
        # @category History Expansion
        # @name !!
        # @desc Expand to the previous command
        bind ! __history_previous_command
        # @category History Expansion
        # @name !$
        # @desc Expand to the last argument of the previous command
        bind '$' __history_previous_command_arguments
    end
end

# Fish command history override to show timestamps
# Shadowing the history command is opinionated (C1 aliasing); when disabled,
# the function is never defined and fish's stock history behavior applies.
if __fish_config_op_enabled (status basename) aliases-tricks
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
# @category Shell Aliases
# @desc cd ..
alias ..='cd ..'
# @category Shell Aliases
# @desc cd ../..
alias ...='cd ../..'
# @category Shell Aliases
# @desc cd ../../..
alias ....='cd ../../..'
# @category Shell Aliases
# @desc cd ../../../..
alias .....='cd ../../../..'
# @category Shell Aliases
# @desc cd ../../../../..
alias ......='cd ../../../../..'

# Silent flag injection into POSIX tools is opinionated (C1 aliasing)
if __fish_config_op_enabled (status basename) aliases-tricks
    # Tools & Core command color overrides
    # @category Shell Aliases
    # @desc dir --color=auto
    alias dir='dir --color=auto'
    # @category Shell Aliases
    # @desc vdir --color=auto
    alias vdir='vdir --color=auto'
    # @category Shell Aliases
    # @desc grep --color=auto
    alias grep='grep --color=auto'
    # @category Shell Aliases
    # @desc fgrep --color=auto
    alias fgrep='fgrep --color=auto'
    # @category Shell Aliases
    # @desc egrep --color=auto
    alias egrep='egrep --color=auto'

    # Safety aliases (Confirmation before overwriting/deleting)
    # @category Shell Aliases
    # @desc cp -i
    alias cp="cp -i"
    # @category Shell Aliases
    # @desc mv -i
    alias mv="mv -i"

    # Force wget to resume partial downloads
    alias wget='wget -c '
end

# Archives and networking short-hands
# @category Shell Aliases
# @desc tar -acf
alias tarnow='tar -acf '
# @category Shell Aliases
# @desc tar -zxvf
alias untar='tar -zxvf '
# @category Shell Aliases
# @desc nc termbin.com 9999
alias tb='nc termbin.com 9999'

# System Logs
# @category Shell Aliases
# @desc journalctl -p 3 -xb
alias jctl="journalctl -p 3 -xb"
