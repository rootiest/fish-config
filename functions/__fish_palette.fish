# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_palette
#
# DESCRIPTION
#   Defines the shared terminal-output colour roles used by the
#   user-facing functions in this configuration. Declared
#   --no-scope-shadowing and using a bare `set`, so the variables are
#   created in the CALLER's scope -- a consumer just calls it and then
#   interpolates $c_head, $c_err and friends exactly as it did when the
#   declarations were inline.
#
#   Call it where the local declarations used to sit, once per contiguous
#   block that needs the palette. set_color runs at call time, so the
#   values track $TERM exactly as inline declarations did. (Measured:
#   set_color output is identical across every TERM tested except
#   TERM=dumb, which yields empty strings, and is unaffected by whether
#   stdout is a tty or a pipe.)
#
#   A role is a semantic slot, not a colour. c_flag and c_warn can both be
#   yellow but stay separate, as do c_ok and c_accent -- merging either
#   pair would foreclose ever restyling one without the other. c_accent is
#   the command name in logs and smart_exit, which style it green where
#   the rest of the config styles it bold.
#
#   c_cmd, c_flag, c_arg, and c_dim are drawn from fish's own highlighter
#   variables (fish_color_command/option/param/autosuggestion) when set,
#   and c_head from the pager's fish_pager_color_prefix -- the same colour
#   a real command, flag, argument, or pager heading gets at the prompt.
#   Each falls back to its previous static default when the theme
#   variable is unset or empty (e.g. a --no-config script).
#
# ARGUMENTS
#   none
#
# EXIT STATUS
#   0  always
#
# EXAMPLE
#   function mytool
#       __fish_palette
#       echo "$c_head""Usage:$c_reset $c_cmd""mytool$c_reset"
#   end
#
# NOTES
#   Calling this at top level (outside any function) creates GLOBAL
#   variables. Every consumer calls it from inside a function, where the
#   variables stay function-local and do not leak.
#
#   functions/fish_prompt.fish deliberately does NOT use this palette. Its
#   c_* values are Catppuccin hex strings passed as ARGUMENTS to set_color
#   (`set_color --bold $c_green`), not captured escape sequences -- colour
#   inputs rather than rendered output, a different concern.

function __fish_palette --no-scope-shadowing --description 'Define the shared output colour palette in the caller scope'
    set c_reset (set_color normal)
    set c_cmd (set_color brblue)
    set c_flag (set_color brgreen)
    set c_arg (set_color cyan)
    set c_dim (set_color brblack)
    set c_head (set_color --bold cyan)
    set c_warn (set_color yellow)
    set c_err (set_color red)
    set c_ok (set_color green)
    set c_accent (set_color green)
    set c_sel (set_color --bold magenta)
    set c_hi (set_color --bold white)

    # Theme overrides: same roles fish's own highlighter/pager use, so
    # --help text matches the prompt instead of a fixed guess at it.
    set -l roles command option param autosuggestion
    set -l vars c_cmd c_flag c_arg c_dim
    for i in (seq (count $roles))
        set -l themevar fish_color_$roles[$i]
        set -q $themevar; and test (count $$themevar) -gt 0
        and set $vars[$i] (set_color $$themevar)
    end
    set -q fish_pager_color_prefix; and test (count $fish_pager_color_prefix) -gt 0
    and set c_head (set_color --bold $fish_pager_color_prefix)
end
