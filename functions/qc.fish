# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# SYNOPSIS
#   qc [prompt...]
#
# DESCRIPTION
#   Quick-chat wrapper around the aichat LLM CLI that defaults to the "cli"
#   role — a system prompt tuned for concise, terminal-friendly output.
#   Resolves the aichat config directory (honoring $XDG_CONFIG_HOME), creates
#   it if missing, and on first use installs the bundled role by symlinking
#   scripts/cli-agent.md to $XDG_CONFIG_HOME/aichat/roles/cli.md. Inherits
#   every aichat flag and tab completion (--wraps aichat); passing --role/-r
#   overrides the default role, so qc forwards to aichat unchanged. The
#   function is only defined when aichat is installed. Run `qc --help` for
#   aichat's full flag reference with the command name rewritten to qc.
#
# ARGUMENTS
#   prompt...     Prompt forwarded to aichat
#   -h, --help    Show usage help
#
# EXIT STATUS
#   aichat's exit status.
#
# EXAMPLE
#   qc "how do I list open ports on linux?"
#   qc -m ollama:llama3 "explain this error"
#   qc --role coder "refactor this function"
if type -q aichat
    function qc --wraps aichat --description 'Quick-chat wrapper around aichat (cli role)'
        if contains -- -h $argv; or contains -- --help $argv
            set -l c_ttl (set_color --bold cyan)
            set -l c_cmd (set_color --bold)
            set -l c_flag (set_color yellow)
            set -l c_txt (set_color normal)
            set -l c_dim (set_color brblack)
            set -l c_rst (set_color normal)
            set -l w 59
            set -l bar (string repeat -n $w ─)
            # Title line, padded to the box width (plain form drives the math).
            set -l title "  qc — quick-chat: a thin aichat wrapper"
            set -l pad (string repeat -n (math $w - (string length -- $title)) ' ')
            echo "$c_dim╭$bar╮$c_rst"
            echo "$c_dim│$c_rst  $c_ttl""qc$c_rst $c_dim—$c_rst quick-chat: a thin $c_cmd""aichat$c_rst wrapper$pad$c_dim│$c_rst"
            echo "$c_dim╰$bar╯$c_rst"
            echo "  Defaults to the $c_flag'cli'$c_rst role — an AI system prompt tuned"
            echo "  for concise, $c_txt""terminal-friendly$c_rst output."
            echo
            echo "  Accepts every $c_cmd""aichat$c_rst flag; passing $c_flag--role$c_rst/$c_flag-r$c_rst overrides"
            echo "  the default role. $c_cmd""aichat$c_rst's own help follows:"
            echo "$c_dim$bar$c_rst"
            aichat --help | string replace -a aichat qc
            return 0
        end

        set -q XDG_CONFIG_HOME; or set -l XDG_CONFIG_HOME $HOME/.config
        set -l role $XDG_CONFIG_HOME/aichat/roles/cli.md

        if not test -e $role
            set -l src (path resolve (status dirname)/../scripts/cli-agent.md)
            mkdir -p (path dirname $role)
            ln -s $src $role
        end

        # Forward as-is if the user already picked a role; otherwise default to cli.
        if contains -- -r $argv; or contains -- --role $argv; or string match -qr -- '^--role=' $argv
            aichat $argv
        else
            aichat --role cli $argv
        end
    end
end
