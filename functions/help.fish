# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#    help [topic] [sub-topic...]
#
# DESCRIPTION
#    Wraps the built-in Fish help command. Intercepts the specific topic "config" 
#    and forwards any subsequent sub-topics/arguments straight to the custom 
#    'config-help' utility. For all other topics, it forwards the arguments 
#    intact to the original, built-in system help utility.
#
# ARGUMENTS
#    topic       Optional string representing the primary help subject (e.g., "config").
#    sub-topic   Optional additional arguments passed exclusively to 'config-help'.
#
# RETURNS
#    0   Successful execution of config-help or the original system help command.
#    >0  Failure status returned by the underlying help utilities.
#
# NOTES
#    To prevent infinite recursion, the wrapper must backup the native system function 
#    on the first run. Because Fish lazy-loads functions dynamically, we explicitly 
#    source the system file and clone it to '__original_help' if it doesn't already exist.
#
# EXAMPLE
#    help config keys
#    # Executes: config-help keys
#
#    help string
#    # Forwards to the standard fish documentation for 'string'

# --- Initialization & Backup ---
if not functions -q __original_help
    source $__fish_data_dir/functions/help.fish
    functions -c help __original_help
end

# --- Wrapper Definition ---
function help --wraps help --description "Custom wrapper to intercept 'help config'"
    if test "$argv[1]" = config
        # Pass every argument after 'config' to the config-help function
        config-help $argv[2..]
    else
        __original_help $argv
    end
end
