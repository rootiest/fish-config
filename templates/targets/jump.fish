# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  jump
# KIND      target
# SUMMARY   Go to a directory and stay there, optionally running a command line
# PHRASE    Goes to {jump_dir} and stays there
# SYNOPSIS  {name} [ARGS...]
# STATUS    Exit status of the command line; 1 if {jump_dir} cannot be entered; 2 for arguments with no command line
# EXAMPLE   {name}

#   ─────────────────────────────── Settings ───────────────────────────────

# Directory to go to. (path, required)
set -l jump_dir

# Command line to run there, if any; your arguments are added to the end.
set -l jump_cmd

#   ─────────────────────────── Fragment: guard ────────────────────────────

if test -z "$jump_cmd"; and set -q argv[1]
    echo (status current-function)": takes no arguments" >&2
    return 2
end

#   ──────────────────────────── Fragment: seed ────────────────────────────

# Unlike in-dir, nothing changes back afterwards. The old directory goes
# on $dirprev, as cd does, so cd - and prevd lead back.
set -l __ft_from $PWD
builtin cd $jump_dir; or return 1
test "$PWD" != "$__ft_from"; and set -g -a dirprev $__ft_from

#   ──────────────────────────── Fragment: run ─────────────────────────────

set __ft_status 0
if test -n "$jump_cmd"
    eval $jump_cmd (string escape -- $argv)
    set __ft_status $status
end
