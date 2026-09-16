# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   03-editors-and-viewers
#
# DEPENDENCIES
#   marktext, firejail, bkg
#
# SYNOPSIS
#   md [-r] [--foreground] [marktext-args...] [FILE...]
#
# DESCRIPTION
#   Opens files in MarkText, detached from the terminal so the shell stays
#   usable and the editor survives closing the window that launched it.
#
#   Every argument is forwarded to marktext untouched except the two flags
#   below, which md consumes itself. marktext's own flags (--new-window,
#   --safe, --disable-gpu, ...) therefore work exactly as documented in
#   marktext --help.
#
#   Flags whose entire purpose is terminal output -- --version, -v/--verbose
#   and --debug -- imply --foreground, since backgrounding them would send
#   the output you asked for to /dev/null.
#
#   --read-only sandboxes the editor with firejail so saving fails instead of
#   overwriting the file. MarkText has no read-only mode of its own.
#
# ARGUMENTS
#   FILE...            Markdown files to open
#   -r, --read-only    Open sandboxed, with every named file bound read-only
#   --foreground       Run in the foreground; do not detach
#   -h, --help         Show this help message
#
# EXIT STATUS
#   0  MarkText launched (or, with --foreground, exited successfully)
#   1  --read-only was requested without firejail or without an existing file
#
# EXAMPLE
#   md README.md
#   md --read-only NOTES.md
#   md --foreground --debug draft.md
#   md --new-window one.md two.md
#
# NOTES
#   This file is autoloaded, so it never shadows an md function or alias
#   defined elsewhere -- fish only looks here when nothing named md exists.
#   A real md *binary* would be shadowed, so md hands off to it verbatim
#   whenever marktext is not installed.
function md --wraps marktext --description 'Launch MarkText detached from the terminal'
    # Without marktext this wrapper has nothing to offer, so give the name
    # back to whatever md the system does provide.
    if not type -q marktext
        command md $argv
        return $status
    end

    __fish_help_header (status current-function) $argv; and return 0

    # Split our own two flags out of the argument list. Everything else is
    # marktext's business and is forwarded verbatim.
    set -l read_only 0
    set -l foreground 0
    set -l args
    for arg in $argv
        switch $arg
            case -r --read-only
                set read_only 1
            case --foreground
                set foreground 1
            case '*'
                set -a args $arg
        end
    end

    # Backgrounding a flag that exists to print something defeats it.
    for flag in --version -v --verbose --debug
        if contains -- $flag $args
            set foreground 1
            break
        end
    end

    set -l cmd marktext $args

    if test $read_only -eq 1
        if not type -q firejail
            echo "md: --read-only requires firejail" >&2
            return 1
        end

        # firejail rejects relative --read-only targets.
        set -l ro_flags
        for arg in $args
            if test -e $arg
                set -a ro_flags --read-only=(path resolve $arg)
            end
        end
        if test (count $ro_flags) -eq 0
            echo "md: --read-only needs an existing file to protect" >&2
            return 1
        end

        # MarkText is single-instance: a plain launch hands the file to an
        # already-running -- unsandboxed, writable -- window and exits,
        # silently defeating the sandbox. A private user-data directory
        # forces an independent instance that the read-only bind covers.
        set -l cache (set --query XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo "$HOME/.cache")
        set -l ro_data "$cache/marktext-readonly"
        mkdir -p $ro_data
        or return 1

        # --no-sandbox: Electron's own sandbox needs user namespaces that
        # firejail has already taken away.
        set cmd firejail $ro_flags marktext --no-sandbox --user-data-dir=$ro_data $args
    end

    if test $foreground -eq 1
        $cmd
        return $status
    end

    bkg $cmd
end
