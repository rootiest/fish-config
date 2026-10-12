# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  command
# KIND      target
# SUMMARY   Run one command, passing your arguments through
# PHRASE    Runs {command_cmd}
# SYNOPSIS  {name} [ARGS...]
# STATUS    Exit status of {command_cmd}; 127 if it is not installed
# EXAMPLE   {name}

#   ─────────────────────────────── Settings ───────────────────────────────

# Command to run, with any fixed arguments. (list, required)
set -l command_cmd

#   ──────────────────────────── Fragment: seed ────────────────────────────

# A function named after the command it wraps must call the binary, or it
# would call itself forever. Fish refuses to expand a variable that starts
# with the word `command`, so resolve the binary to its path instead.
if test "$command_cmd[1]" = (status current-function)
    set -l __ft_bin (command -s $command_cmd[1]); or begin
        echo (status current-function)": $command_cmd[1]: command not found" >&2
        return 127
    end
    set cmd $__ft_bin $command_cmd[2..]
else
    set cmd $command_cmd
end

#   ──────────────────────────── Fragment: run ─────────────────────────────

$cmd $argv $__ft_append
set __ft_status $status
