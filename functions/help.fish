# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#    help [topic] [sub-topic...]
#    help config [section] [-w|--html] [-m|--man] [-h|--help]
#
# DESCRIPTION
#    Wraps the built-in Fish help command. Intercepts the specific topic "config"
#    and forwards any subsequent sub-topics/arguments straight to the custom
#    'config-help' utility. For all other topics, it forwards the arguments
#    intact to the original, built-in system help utility.
#
#    When the first argument is "config", the following flags are recognized
#    and delegated to 'config-help':
#      -w, --html   Open the offline HTML docs in the default browser
#      -m, --man    Open the compiled man page via man -l
#      -h, --help   Print config-help usage reference
#
#    Flags that appear WITHOUT a leading "config" argument — including -h/--help —
#    are forwarded unchanged to the native Fish help command, so built-in
#    behavior is never overridden for non-config topics.
#
# ARGUMENTS
#    topic        Optional primary help subject (e.g., "config").
#    sub-topic    Optional additional arguments passed to 'config-help'.
#    section      Keyword to jump to a section (only when topic is "config").
#    -w, --html   Open HTML docs (only when topic is "config").
#    -m, --man    Open man page (only when topic is "config").
#    -h, --help   Print config-help usage (only when topic is "config");
#                 otherwise forwarded to the native Fish help.
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
#    help config --html
#    # Opens the offline HTML docs in the default browser
#
#    help config keys --man
#    # Opens the compiled man page via man -l
#
#    help config --help
#    # Prints the config-help usage reference
#
#    help string
#    # Forwards to the standard fish documentation for 'string'
#
#    help --help
#    # Forwards to the native Fish help command (not intercepted)

# --- Initialization & Backup ---
if not functions -q __original_help
    source $__fish_data_dir/functions/help.fish
    functions -c help __original_help
end

# --- Wrapper Definition ---
function help --wraps help --description "Custom wrapper to intercept 'help config'"
    # Opinionated guard (C1): fall back to the native fish help when disabled.
    if not __fish_config_op_enabled __fish_config_op_aliases
        __original_help $argv
        return $status
    end

    if test "$argv[1]" = config
        # All arguments after 'config' — including flags (-w/--html, -m/--man,
        # -h/--help) and section keywords — are forwarded to config-help.
        # Flags are only intercepted here when 'config' is the first argument,
        # so native fish help flags are never shadowed for other topics.
        config-help $argv[2..]
    else
        __original_help $argv
    end
end
