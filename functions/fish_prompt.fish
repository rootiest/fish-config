# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   fish_prompt
#
# DESCRIPTION
#   Catppuccin Mocha fallback prompt (nim-style, two-line). Active whenever
#   the starship prompt is not available — either starship is not installed or
#   C3 overrides are disabled. Has no external dependencies; uses only fish
#   builtins (set_color, fish_git_prompt, prompt_pwd, prompt_hostname).
#
# RETURNS
#   0  Always; outputs the prompt to stdout
#
# EXAMPLE
#   # Rendered automatically by fish; not called directly.
function fish_prompt
    set -l last_status $status

    # Catppuccin Mocha hex palette
    set -l c_green  a6e3a1
    set -l c_red    f38ba8
    set -l c_yellow f9e2af
    set -l c_text   cdd6f4
    set -l c_blue   89b4fa
    set -l c_teal   94e2d5
    set -l c_pink   f5c2e7
    set -l c_dim    6c7086
    set -l c_mauve  cba6f7

    # Line/connector color tracks last exit status; brackets stay bold green
    set -l retc $c_green
    test $last_status -ne 0; and set retc $c_red

    # Enable upstream arrows in git prompt (↑/↓)
    set -q __fish_git_prompt_showupstream
    or set -g __fish_git_prompt_showupstream auto

    # ─── First line ───────────────────────────────────────────────────────────
    set_color $retc
    echo -n '┬─'
    set_color --bold $c_green
    echo -n '['

    # Username: red if root, yellow otherwise
    if functions -q fish_is_root_user; and fish_is_root_user
        set_color --bold $c_red
    else
        set_color --bold $c_yellow
    end
    echo -n $USER

    set_color --bold $c_text
    echo -n '@'

    # Hostname: teal if SSH, blue if local
    if test -n "$SSH_CLIENT"
        set_color --bold $c_teal
    else
        set_color --bold $c_blue
    end
    echo -n (prompt_hostname)

    set_color --bold $c_text
    echo -n ':'
    set_color $c_text
    echo -n (prompt_pwd)
    set_color --bold $c_green
    echo -n ']'
    set_color normal

    # Vi-mode segment ─[N/I/R/V]
    if test "$fish_key_bindings" = fish_vi_key_bindings
        or test "$fish_key_bindings" = fish_hybrid_key_bindings
        set -l mode_str
        switch $fish_bind_mode
            case default
                set mode_str (set_color --bold $c_red)'N'(set_color normal)
            case insert
                set mode_str (set_color --bold $c_green)'I'(set_color normal)
            case replace_one replace
                set mode_str (set_color --bold $c_teal)'R'(set_color normal)
            case visual
                set mode_str (set_color --bold $c_mauve)'V'(set_color normal)
        end
        set_color $retc
        echo -n '─'
        set_color --bold $c_green
        echo -n '['
        echo -n $mode_str
        set_color --bold $c_green
        echo -n ']'
        set_color normal
    end

    # Virtual environment segment ─[V:name]
    set -q VIRTUAL_ENV_DISABLE_PROMPT
    or set -g VIRTUAL_ENV_DISABLE_PROMPT true
    if set -q VIRTUAL_ENV
        set_color $retc
        echo -n '─'
        set_color --bold $c_green
        echo -n '['
        set_color normal
        set_color $retc
        echo -n 'V:'(path basename "$VIRTUAL_ENV")
        set_color --bold $c_green
        echo -n ']'
        set_color normal
    end

    # Git branch in Catppuccin Pink, wrapped in parens: (main)
    set -l git_info (fish_git_prompt '%s')
    if test -n "$git_info"
        echo -n ' '
        set_color $c_pink
        echo -n "($git_info)"
        set_color normal
    end

    echo  # newline

    # Background jobs (one per line, dim)
    for job in (jobs)
        set_color $retc
        echo -n '│ '
        set_color $c_dim
        echo $job
    end

    # ─── Second line ──────────────────────────────────────────────────────────
    set_color $retc
    echo -n '╰─>'
    set_color --bold $c_red
    echo -n '$ '
    set_color normal
end
