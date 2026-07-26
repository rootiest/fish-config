---
title: Editors and Viewers
manTitle: 5.3 Editors and Viewers
sidebar:
  order: 3
helpKeywords:
- editors
---

## edit

    Synopsis:  edit [-V|-t] [-e EDITOR] [-c] [-x TEXT] [-n] [-v|-s] [FILE...]

    Opens files in a text editor, choosing a terminal or GUI editor and
    resolving a rich chain of fallbacks. With no --visual/--terminal flag the
    mode is auto-detected: interactive terminals use the terminal editor
    ($EDITOR), while detached invocations (e.g. desktop shortcuts) use the GUI
    editor ($VISUAL). Clipboard contents and literal strings can be opened as
    throwaway temp files. Editor output is suppressed unless --verbose.

    GUI fallback chain:      zed → antigravity-ide → code → kate → kwrite →
                             gnome-text-editor → gedit
    Terminal fallback chain: nvim → vim → micro → nano → vi

    Options:
      -V, --visual      Force the GUI editor ($VISUAL or fallbacks)
      -t, --terminal    Force the terminal editor ($EDITOR or fallbacks)
      -e, --editor=X    Use a specific editor binary X
      -c, --clipboard   Open the clipboard contents (as a temp file)
      -x, --text=STR    Open STR as the contents of a new temp file
      -n, --new         Force a new window/instance (best-effort)
      -v, --verbose     Print the launch command and editor output
      -s, --silent      Suppress all output, including the editor's
      -h, --help        Show this help message

    edit ~/.config/fish/config.fish
    edit --visual notes.txt
    edit --terminal --new todo.md
    edit --editor=code --clipboard
    edit --text="hello world"

## fc

    Synopsis:  fc [command_prefix]
    Edit the last shell command (or one matching a prefix) in $EDITOR,
    then execute the result. Bash-style fc behaviour.

    fc
    fc git

## less

    Synopsis:  less [args...]
    Pager wrapper with fallback chain: $PAGER -> ov -> less -> more -> cat.

    less /var/log/syslog

## rawfish

    Synopsis:  rawfish [args...]
    Launches Fish with NO_TMUX=1, bypassing any tmux auto-attach logic.
    Useful when you need a clean shell without session management.

## view

    Synopsis:  view [args...]
    Opens files in nvim read-only mode (-R). Falls back to less.

    view /etc/fstab

---
