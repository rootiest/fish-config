---
title: Key Bindings
manTitle: 3. KEY BINDINGS
sidebar:
  order: 7
helpKeywords:
- keybindings
- bindings
- key-bindings
- keys
---

The shell uses Vi key bindings (fish_vi_key_bindings). All custom bindings
are active in Insert, Normal, and Visual modes unless noted.

    Binding         Action
    ─────────────────────────────────────────────────────────────────────
    Ctrl+G          Insert the head of the previous command's last path
                    argument. Equivalent to !$:h in Bash.
                    Example: previous = "cd /usr/local/bin"
                             Ctrl+G inserts "/usr/local"

    Ctrl+F          Interactive history substitution. Type old/new then
                    press Ctrl+F to apply s/old/new/ to the previous
                    command. Equivalent to !!:s/old/new/ in Bash.
                    Example: previous = "echo this is a test"
                             type "this is/that was", press Ctrl+F
                             result = "echo that was a test"

    Ctrl+Alt+U      Strip the first token of the current command line,
                    leaving arguments in place with the cursor at the
                    start. Useful for quickly retyping the command. On
                    an empty command line, first recalls the most recent
                    history entry (like Up), then strips its first token.
                    Example: "mkdir new_folder" -> " new_folder"
                    Example: empty line after "cd /home/me" -> " /home/me"

    Ctrl+Alt+W      Remove the last argument of the current command line
                    and leave the cursor where it was, ready to retype.
                    Repeat to pop consecutive arguments. Quoted arguments
                    pop as one token. The command word is never removed
                    (use Ctrl+Alt+U for that). On an empty command line,
                    first recalls the most recent history entry.
                    Example: "cp a b c" -> "cp a b " -> "cp a " -> "cp "

    Ctrl+Alt+=      Evaluate the current command line buffer with
                    Qalculate! (qalc) and print the result inline.
                    Requires qalc to be installed.
                    Example: type "150 * 1.08", press Ctrl+Alt+=
                             prints 162

    Ctrl+Enter      Smart execute: runs commands instantly without
                    pressing Enter a second time for certain fast-path
                    commands (speedtest-fast, etc.).

    @@              FZF inline picker. Type @ twice anywhere on the
                    command line to open an fzf picker and replace the
                    @@ with the selection. The @@ must be typed as its
                    own token: "cat @@" triggers it, but "cat@@" does
                    not.

    Ctrl+Left       Move the cursor one whole token (argument) at a
    Ctrl+Right      time, so a path like ~/.claude/AGENTS.md is a single
                    stop. Ctrl+Right at the end of the line accepts the
                    autosuggestion one token at a time.
                    For finer stops at each / and . (and accepting an
                    autosuggestion one directory segment at a time),
                    switch both directions to word motion:
                        set -U __fish_ctrl_arrow_motion word
                    Erase it to return to token motion:
                        set -Ue __fish_ctrl_arrow_motion
                    Takes effect in new shells, or run
                    fish_user_key_bindings in the current one.

    Alt+Left        Move by word, stopping at each / and . so a path
    Alt+Right       is walked one segment at a time (stock fish).
                    Alt+Right at the end of the line accepts the
                    autosuggestion one segment at a time. On an empty
                    command line they step back/forward through the
                    directory history (prevd/nextd) instead.

## FZF Bindings

Bundled from PatrickF1/fzf.fish.

    Ctrl+R          Search command history
    Ctrl+Alt+F      Search git-tracked files
    Ctrl+Alt+L      Search git log
    Ctrl+Alt+S      Search git status
    Ctrl+V          Search shell variables
    Ctrl+Alt+P      Search running processes

---
