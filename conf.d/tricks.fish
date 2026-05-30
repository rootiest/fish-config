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

# Format man pages using bat (only if bat is installed)
if type -q bat
    set -gx MANROFFOPT -c
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

# Set settings for https://github.com/franciscolourenco/done
set -gx __done_min_cmd_duration 10000
set -gx __done_notification_urgency_level low

## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
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

# Fish command history override to show timestamps
function history
    builtin history --show-time='%F %T '
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

# Tools & Core command color overrides
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Safety aliases (Confirmation before overwriting/deleting)
alias cp="cp -i"
alias mv="mv -i"

# Archives and networking short-hands
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias tb='nc termbin.com 9999'

# System Logs
alias jctl="journalctl -p 3 -xb"
