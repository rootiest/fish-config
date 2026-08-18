# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   03-editors-and-viewers
#
# COMPONENT
#   aliases/dev-tools
#
# SYNOPSIS
#   edit [-V|-t] [-e EDITOR] [-c] [-x TEXT] [-n] [-v|-s] [FILE...]
#
# DESCRIPTION
#   Opens files in a text editor, choosing a terminal or GUI editor and
#   resolving a rich chain of fallbacks. With no --visual/--terminal flag the
#   mode is auto-detected: interactive terminals get the terminal editor
#   ($EDITOR), while detached invocations (desktop shortcuts) get the GUI
#   editor ($VISUAL). Clipboard contents and literal strings can be opened as
#   throwaway temp files. Editor output is suppressed unless --verbose.
#
#   GUI fallback chain:      zed → antigravity-ide → code → kate → kwrite →
#                            gnome-text-editor → gedit
#   Terminal fallback chain: nvim → vim → micro → nano → vi
#
# ARGUMENTS
#   FILE...           Files to open (any number)
#   -V, --visual      Force the GUI editor ($VISUAL or fallbacks)
#   -t, --terminal    Force the terminal editor ($EDITOR or fallbacks)
#   -e, --editor=X    Use a specific editor binary X
#   -c, --clipboard   Open the clipboard contents (as a temp file)
#   -x, --text=STR    Open STR as the contents of a new temp file
#   -n, --new         Force a new window/instance (best-effort, where supported)
#   -v, --verbose     Print the launch command and let editor output through
#   -s, --silent      Suppress all output, including the editor's
#   -h, --help        Show this help message
#
# EXIT STATUS
#   0  Editor launched successfully
#   1  Conflicting flags, no editor found, or clipboard read failed
#
# EXAMPLE
#   edit notes.txt
#   edit --visual ~/.config/fish/config.fish
#   edit --terminal --new todo.md
#   edit --editor=code --clipboard
#   edit --text="hello world"
function edit --description 'Open files in a terminal or GUI editor with fallbacks'
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold white)
    set -l c_flag (set_color yellow)
    set -l c_err (set_color red)
    set -l c_dim (set_color brblack)
    set -l c_reset (set_color normal)

    # Opinionated guard (C1): fall back to the legacy bare-editor behavior.
    if not __fish_config_op_enabled (status current-function)
        if set -q EDITOR; and test -n "$EDITOR"
            $EDITOR $argv
        else if type -q nvim
            nvim $argv
        else if type -q nano
            nano $argv
        else
            vi $argv
        end
        return $status
    end

    argparse h/help V/visual t/terminal 'e/editor=' c/clipboard 'x/text=' \
        n/new v/verbose s/silent -- $argv
    or return 1

    if set -q _flag_help
        echo "$c_head""Usage:$c_reset $c_cmd""edit$c_reset $c_flag""[-V|-t] [-e EDITOR] [-c] [-x TEXT] [-n] [-v|-s]$c_reset $c_dim""[FILE...]$c_reset"
        echo
        echo "  Open files in a terminal or GUI editor, with auto-detection and fallbacks."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-V$c_reset, $c_flag--visual$c_reset      Force the GUI editor (\$VISUAL or fallbacks)"
        echo "  $c_flag-t$c_reset, $c_flag--terminal$c_reset    Force the terminal editor (\$EDITOR or fallbacks)"
        echo "  $c_flag-e$c_reset, $c_flag--editor$c_reset $c_dim""X$c_reset   Use a specific editor binary X"
        echo "  $c_flag-c$c_reset, $c_flag--clipboard$c_reset   Open the clipboard contents (as a temp file)"
        echo "  $c_flag-x$c_reset, $c_flag--text$c_reset $c_dim""STR$c_reset   Open STR as the contents of a new temp file"
        echo "  $c_flag-n$c_reset, $c_flag--new$c_reset         Force a new window/instance (best-effort)"
        echo "  $c_flag-v$c_reset, $c_flag--verbose$c_reset     Print the launch command and editor output"
        echo "  $c_flag-s$c_reset, $c_flag--silent$c_reset      Suppress all output, including the editor's"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset        Show this help message"
        return 0
    end

    # Mutually exclusive flag pairs.
    if set -q _flag_visual; and set -q _flag_terminal
        echo "$c_err""edit: --visual and --terminal are mutually exclusive$c_reset" >&2
        return 1
    end
    if set -q _flag_verbose; and set -q _flag_silent
        echo "$c_err""edit: --verbose and --silent are mutually exclusive$c_reset" >&2
        return 1
    end

    #   ──────────────────────── Resolve editor mode ────────────────────────
    set -l mode
    if set -q _flag_visual
        set mode gui
    else if set -q _flag_terminal
        set mode term
    else if status is-interactive; and isatty stdout
        set mode term
    else
        set mode gui
    end

    #   ─────────────────────── Resolve editor binary ───────────────────────
    set -l bin
    if set -q _flag_editor
        if not type -q $_flag_editor
            echo "$c_err""edit: editor not found: $_flag_editor$c_reset" >&2
            return 1
        end
        set bin $_flag_editor
    else if test "$mode" = gui
        if set -q VISUAL; and test -n "$VISUAL"
            set bin $VISUAL
        else
            for c in zed antigravity-ide code kate kwrite gnome-text-editor gedit
                if type -q $c
                    set bin $c
                    break
                end
            end
        end
    else
        if set -q EDITOR; and test -n "$EDITOR"
            set bin $EDITOR
        else
            for c in nvim vim micro nano vi
                if type -q $c
                    set bin $c
                    break
                end
            end
        end
    end
    if test -z "$bin"
        echo "$c_err""edit: no editor found for $mode mode$c_reset" >&2
        return 1
    end

    #   ─────────────────── Assemble the list of files ──────────────────────
    # Positional args first, then synthetic temp files from clipboard/text.
    # Temp files are intentionally left for the OS to reap from /tmp: GUI
    # editors are detached, so we cannot safely remove them mid-edit.
    # ponytail: leak-to-/tmp — add explicit cleanup only if it ever matters.
    set -l files $argv
    if set -q _flag_clipboard
        set -l clip (mktemp --suffix=.txt)
        if p >$clip 2>/dev/null
            set files $files $clip
        else
            echo "$c_err""edit: could not read clipboard$c_reset" >&2
            command rm -f $clip
            return 1
        end
    end
    if set -q _flag_text
        set -l txt (mktemp --suffix=.txt)
        printf '%s\n' "$_flag_text" >$txt
        set files $files $txt
    end

    #   ──────────── Best-effort new-window flag for known editors ───────────
    set -l launch $bin
    if set -q _flag_new
        switch (path basename $bin)
            case kate kwrite
                set launch $launch --new
            case code codium code-insiders zed
                set launch $launch -n
            case gnome-text-editor
                set launch $launch --new-window
                # Unknown editors: --new is ignored (best-effort).
        end
    end
    set launch $launch $files

    if set -q _flag_verbose
        echo "$c_dim→ launching:$c_reset $launch"
    end

    #   ───────────────────────────── Launch ────────────────────────────────
    if test "$mode" = gui
        # Detach GUI editors so the shell stays free.
        if set -q _flag_verbose
            command $launch &
        else
            command $launch &>/dev/null &
        end
        disown
    else
        # Terminal editors must stay in the foreground.
        if set -q _flag_silent
            command $launch 2>/dev/null
        else
            command $launch
        end
    end
end
