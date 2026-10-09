# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   bypasses-shadow(mkdir)
#
# SYNOPSIS
#   _private_dir <dir> [files]
#
# DESCRIPTION
#   Ensures <dir> exists and is private (mode 700), whatever the umask. A
#   missing directory is created with mode 700 (only the leaf; existing
#   parents are left alone). An existing directory whose mode is anything
#   other than 700 is tightened with chmod 700, silently: this runs from
#   shell-startup paths (log setup, pruning), so it never prints.
#
#   With the optional "files" argument, the regular files directly inside
#   <dir> are also set to 600, but only at the moment a laxer directory is
#   tightened. That fixes logs written by earlier versions exactly once,
#   without walking the directory on every use. Subdirectories and their
#   contents are never touched.
#
#   Used by the C5 log writers (_tmux_pipe_log, _zellij_dump_log, smart_exit)
#   and by agents-vault for the vault root.
#
# ARGUMENTS
#   dir    Directory to create or tighten
#   files  Also chmod 600 the top-level regular files when tightening
#
# EXIT STATUS
#   0  <dir> exists and is mode 700
#   1  <dir> could not be created or tightened
#
# EXAMPLE
#   _private_dir ~/.terminal_history files
function _private_dir --argument-names dir files --description 'Create or tighten a directory to mode 700'
    test -n "$dir"; or return 1

    if not test -d "$dir"
        command mkdir -p -m 700 -- "$dir" 2>/dev/null; or return 1
        return 0
    end

    # -L: a symlinked directory is judged (and tightened) by its target.
    set -l mode (command stat -L -c %a -- "$dir" 2>/dev/null)
    if test "$mode" = 700
        return 0
    end

    command chmod 700 -- "$dir" 2>/dev/null; or return 1
    if test "$files" = files
        command find "$dir/" -maxdepth 1 -type f -exec chmod 600 -- '{}' + 2>/dev/null
    end
    return 0
end
