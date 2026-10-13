# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  per-os
# KIND      target
# SUMMARY   Run a different command line on each operating system or distribution
# PHRASE    Runs the command line set for this system ({keys:peros_commands})
# SYNOPSIS  {name} [ARGS...]
# STATUS    Exit status of the command line; 1 if none is set for this system
# EXAMPLE   {name}

#   ─────────────────────────────── Settings ───────────────────────────────

# Command lines, one per line, as system=command line: linux, darwin, freebsd, or a distribution such as arch or debian; a|b matches either, and your arguments are added to the end. (lines, required)
set -l peros_commands

# Command line to run on any other system; empty means fail there.
set -l peros_default

#   ─────────────────────────── Fragment: guard ────────────────────────────

# A system is known by its kernel name (uname -s) and, where
# /etc/os-release exists, its ID and ID_LIKE, all lowercase: arch is also
# linux, ubuntu is also debian. The first matching line wins, so put a
# distribution before linux.
set -l __ft_names (command uname -s | string lower)
if test -r /etc/os-release
    set -a __ft_names (string match -r --groups-only -- '^ID(?:_LIKE)?="?([^"]*)"?$' </etc/os-release | string split -n ' ' | string lower)
end
set -l __ft_line
for __ft_pair in $peros_commands
    set -l __ft_kv (string split -m1 = -- $__ft_pair)
    for __ft_pat in (string split '|' -- (string lower -- $__ft_kv[1]))
        if contains -- $__ft_pat $__ft_names
            set __ft_line $__ft_kv[2]
            break
        end
    end
    test -n "$__ft_line"; and break
end
test -n "$__ft_line"; or set __ft_line $peros_default
if test -z "$__ft_line"
    echo (status current-function)": no command line is set for this system ($__ft_names)" >&2
    return 1
end

#   ──────────────────────────── Fragment: run ─────────────────────────────

eval $__ft_line (string escape -- $argv)
set __ft_status $status
