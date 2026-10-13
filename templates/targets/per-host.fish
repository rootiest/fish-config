# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  per-host
# KIND      target
# SUMMARY   Run a different command line on each machine, by hostname
# PHRASE    Runs the command line set for this machine ({keys:perhost_commands})
# SYNOPSIS  {name} [ARGS...]
# STATUS    Exit status of the command line; 1 if none is set for this machine
# EXAMPLE   {name}

#   ─────────────────────────────── Settings ───────────────────────────────

# Command lines, one per line, as hostname=command line; a|b matches either host, * and ? are wildcards, and your arguments are added to the end. (lines, required)
set -l perhost_commands

# Command line to run on any other machine; empty means fail there.
set -l perhost_default

#   ─────────────────────────── Fragment: guard ────────────────────────────

# Match the full and the short hostname, ignoring case; the first
# matching line wins.
set -l __ft_names (string lower -- $hostname (string split -f1 . -- $hostname))
set -l __ft_line
for __ft_pair in $perhost_commands
    set -l __ft_kv (string split -m1 = -- $__ft_pair)
    for __ft_pat in (string split '|' -- (string lower -- $__ft_kv[1]))
        if string match -q -- $__ft_pat $__ft_names
            set __ft_line $__ft_kv[2]
            break
        end
    end
    test -n "$__ft_line"; and break
end
test -n "$__ft_line"; or set __ft_line $perhost_default
if test -z "$__ft_line"
    echo (status current-function)": no command line is set for host '$hostname'" >&2
    return 1
end

#   ──────────────────────────── Fragment: run ─────────────────────────────

eval $__ft_line (string escape -- $argv)
set __ft_status $status
