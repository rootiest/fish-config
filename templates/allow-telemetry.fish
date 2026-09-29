# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#   ╭──────────────────────────────────────────────────────────────────────╮
#   │                   TEMPLATE: allow-telemetry wrapper                  │
#   ╰──────────────────────────────────────────────────────────────────────╯
#
# Wraps one command and removes environment variables from that command's
# process only. Every other tool still sees them.
#
# Use it when a global opt-out (DO_NOT_TRACK, DISABLE_TELEMETRY) breaks a
# feature you want in one tool. Example: claude-code needs feature flags for
# Remote Control, and both variables turn them off.
#
# To use:
#   1. Set wrap_cmd and wrap_unset below.
#   2. Save the file as <wrap_cmd>.fish in a directory on $fish_function_path,
#      e.g. $__fish_user_dots_path/functions/ or $__fish_config_dir/functions/.
#      Fish autoloads a function by its file name.
#   3. Update the documentation header below for the new command.

#   ─────────────────────────────── Settings ───────────────────────────────

# Command to wrap. Must match the file name (claude -> claude.fish).
set -l wrap_cmd claude

# Variables removed from the wrapped command's environment.
set -l wrap_unset DO_NOT_TRACK DISABLE_TELEMETRY

#   ─────────────────────────────── Function ───────────────────────────────

# SYNOPSIS
#   claude [ARGS...]
#
# DESCRIPTION
#   Runs the claude binary without DO_NOT_TRACK and DISABLE_TELEMETRY in its
#   environment. The variables stay set in the calling shell and in every
#   other command. All arguments are forwarded verbatim.
#
# ARGUMENTS
#   ARGS  Any arguments forwarded verbatim to the underlying binary
#
# EXIT STATUS
#   Exit status of the underlying binary; 127 if it is not installed
#
# EXAMPLE
#   claude --remote-control
#
# NOTES
#   The function name and settings are fixed when the file loads (-V
#   snapshots them), so the file-scope variables above do not leak into the
#   shell. `env` runs the external binary, never this function, so the
#   wrapper cannot recurse.
function $wrap_cmd --wraps=$wrap_cmd -V wrap_cmd -V wrap_unset --description "$wrap_cmd with $wrap_unset removed from its environment"
    set -l env_args
    for var in $wrap_unset
        set -a env_args -u $var
    end
    env $env_args $wrap_cmd $argv
end
