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
                    start. Useful for quickly retyping the command.
                    Example: "mkdir new_folder" -> " new_folder"

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
                    own token: "test @@" triggers it, but "test@@" does
                    not.

    Ctrl+Right      Accept autosuggestion one word/directory segment
                    at a time. (Restores Fish 3.x behavior by binding
                    to nextd-or-forward-word).

## FZF Bindings (bundled from PatrickF1/fzf.fish)

    Ctrl+R          Search command history
    Ctrl+Alt+F      Search git-tracked files
    Ctrl+Alt+L      Search git log
    Ctrl+Alt+S      Search git status
    Ctrl+V          Search shell variables
    Ctrl+Alt+P      Search running processes

---
