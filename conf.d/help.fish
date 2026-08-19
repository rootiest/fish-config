# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
#          ╭──────────────────────────────────────────────────────────╮
#          │                  help config wrapper                     │
#          ╰──────────────────────────────────────────────────────────╯
#
# COMPONENT
#    aliases/shell-tools
#
# SYNOPSIS
#    help [topic] [sub-topic...]
#    help config [section] [-w|--html] [-m|--man] [-h|--help]
#
# DESCRIPTION
#    Wraps the built-in Fish help command. Intercepts the specific topic
#    "config" and forwards any subsequent sub-topics/arguments straight to the
#    custom 'config-help' utility. For all other topics, it forwards the
#    arguments intact to the original, built-in system help utility.
#
#    When the first argument is "config", the following flags are recognized
#    and delegated to 'config-help':
#      -w, --html   Open the offline HTML docs in the default browser
#      -m, --man    Open the compiled man page via man -l
#      -h, --help   Print config-help usage reference
#
#    Flags that appear WITHOUT a leading "config" argument — including
#    -h/--help — are forwarded unchanged to the native Fish help command, so
#    built-in behavior is never overridden for non-config topics.
#
# NOTES
#    To prevent infinite recursion, the wrapper backs up the native help
#    function as '__original_help' before shadowing it. This MUST happen from
#    conf.d, not functions/help.fish: as of Fish 4.x the native help is
#    embedded in the binary (embedded:functions/help.fish) with no on-disk
#    file to source, and a functions/help.fish autoload shadow makes the name
#    'help' resolve to our own wrapper (or nothing, mid-autoload) — so the
#    backup could never capture the real help. Sourced here at startup, before
#    any shadow exists, `functions -c help` copies the embedded original.
#
# EXAMPLE
#    help config keys          # → config-help keys
#    help config --html        # opens the offline HTML docs in the browser
#    help config keys --man    # opens the compiled man page via man -l
#    help string               # forwards to native fish docs for 'string'

# --- Initialization & Backup ---
# Copy the native (embedded) help to __original_help before we shadow it.
if not functions -q __original_help
    functions -c help __original_help
end

# --- Wrapper Definition ---
function help --wraps help --description "Custom wrapper to intercept 'help config'"
    # Opinionated guard (C1): fall back to the native fish help when disabled.
    if not __fish_config_op_enabled (status current-function)
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
