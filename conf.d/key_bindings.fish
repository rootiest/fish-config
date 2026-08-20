# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
#          ╭──────────────────────────────────────────────────────────╮
#          │                  Fish User Key Bindings                  │
#          ╰──────────────────────────────────────────────────────────╯
#
# This file defines custom key bindings for the Fish shell.
# It is sourced by Fish on startup.

# COMPONENT
#   overrides/key-bindings

# ────────────────── Bind Prewious Path Head to Ctrl+G ─────────────────
# Bindings to insert the previous path head into the command line
# Behaves like `!$:h` does in bash
#
# Example: If the previous command was `cd /usr/local/bin`
# pressing Ctrl+G will insert `/usr/local` into the command line.
# ──────────────────────────────────────────────────────────────────────

# ──────────── Bind Interactive History Substitution to Ctrl+F ─────────
# Bindings to perform substitution on the previous command in the history
# Behaves like `!!:s/old/new/` does in bash
# 
# Example: If the previous command was `echo this is a test`
# typing `this is/that was` and pressing Ctrl+F
# will insert `echo that was a test` into the command line.
# ──────────────────────────────────────────────────────────────────────

# ────────── Bind Replace First Command Token to Ctrl+Alt+U ────────────
# Strips the first command token and places cursor at start to retype it
#
# Example: If the current command text is `mkdir new_folder`
# pressing Ctrl+Alt+U will change the command line to ` new_folder`
# with the cursor at the start, allowing you to quickly change the command
# while keeping the arguments intact.
# To produce `cd new_folder` or `rm new_folder` etc.
# If the current command text is empty, the previous command's first token will be used instead.
# ──────────────────────────────────────────────────────────────────────

# ────────────── Bind Quick Qalc Evaluation to Ctrl+Alt+= ──────────────
# Passes the current command line buffer to the Qalculate! CLI (qalc)
#
# Example: If you type `150 * 1.08` and press Ctrl+Alt+=, 
# it will print the result (162) and clear the command line.
# This allows for rapid-fire math without leaving the current shell.
# ──────────────────────────────────────────────────────────────────────

function fish_user_key_bindings

    # Custom key chords are opinionated (C3 overrides); skip them entirely
    # when overrides are disabled so stock bindings remain untouched.
    # NOTE: (status basename), not (status current-function) -- this guard
    # lives inside fish's own reserved fish_user_key_bindings function, whose
    # name is not this file's identity; the registry key is this file's
    # bare basename, key_bindings.
    __fish_config_op_enabled (status basename); or return

    #   ───────────────────────────── Set Bindings ─────────────────────────────
    #
    # Set Emacs mode bindings:
    bind ctrl-g __insert_previous_path_head
    bind ctrl-f __interactive_history_sub
    bind ctrl-alt-u _replace_command_token
    type -q qalc && bind ctrl-alt-= _qalc_eval
    bind ctrl-enter _smart_execute
    bind ctrl-right nextd-or-forward-word
    bind \e\[1\;5C nextd-or-forward-word

    # Set bindings for all Vi modes:
    # 'default' is Vi-Command, 'insert' is Vi-Insert, 'visual' is Vi-Visual
    for mode in default insert visual
        bind --mode $mode ctrl-g __insert_previous_path_head
        bind --mode $mode ctrl-f __interactive_history_sub
        bind --mode $mode ctrl-alt-u _replace_command_token
        type -q qalc && bind --mode $mode ctrl-alt-= _qalc_eval
        bind --mode $mode ctrl-enter _smart_execute
        bind --mode $mode ctrl-right nextd-or-forward-word
        bind --mode $mode \e\[1\;5C nextd-or-forward-word
    end

    # @ is Emacs/Vi-insert only. Emacs bindings and Vi's "default" (normal)
    # mode share the same bind_mode name, so a mode-less `bind @` would also
    # land in Vi normal mode, turning its current no-op @ into a self-insert.
    # Register the mode-less form only when Vi bindings aren't the active
    # base, and rely on the explicit insert-mode bind otherwise.
    if test "$fish_key_bindings" != fish_vi_key_bindings
        bind @ __fzf_inline_picker
    end
    bind --mode insert @ __fzf_inline_picker
end
