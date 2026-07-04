# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_set_value <varname> <type> <value>
#
# DESCRIPTION
#   Sets a universal config variable from a config-settings value page,
#   immediately and persistently. An empty <value> erases the variable so the
#   built-in default takes over. List types split <value> on whitespace; all
#   other types store it as a single value. When <varname> is a scrollback
#   variable, the exported SCROLLBACK_HISTORY_* mirror is re-derived so the
#   POSIX wrappers in the live session see the change without a re-login.
#
# ARGUMENTS
#   varname  Variable name without the $ prefix
#   type     "list" (whitespace-split) or any other tag (single value)
#   value    The new value; empty string erases (reset to default)
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   __config_settings_set_value sponge_delay int 5
#   __config_settings_set_value sponge_successful_exit_codes list "0 1 130"
#   __config_settings_set_value __fish_scrollback_history_dir path ~/logs
#   __config_settings_set_value __fish_user_dots_path path ''   # reset
function __config_settings_set_value
    set -l varname $argv[1]
    set -l type    $argv[2]
    set -l value   $argv[3]

    # stderr suppressed: editing a universal while a global of the same name
    # shadows it makes interactive fish emit a shadow warning that would
    # corrupt the in-place panel redraw (see __config_settings_apply).
    if test -z "$value"
        set -Ue $varname 2>/dev/null
    else
        switch $type
            case list
                # Accept commas and/or whitespace as separators: collapse any run
                # of them to a single space, then split (dropping empties). So
                # "A,B", "A, B", "A  B" and "A B" all yield the same two tokens.
                set -U -- $varname \
                    (string split -n ' ' -- (string replace -ra '[,\s]+' ' ' -- $value)) 2>/dev/null
            case '*'
                # -- (before the name) guards typed input that begins with a dash
                set -U -- $varname $value 2>/dev/null
        end
    end

    # Scrollback export mirror — POSIX wrappers read these from the env.
    switch $varname
        case __fish_scrollback_history_dir
            if set -q __fish_scrollback_history_dir
                set -gx SCROLLBACK_HISTORY_DIR $__fish_scrollback_history_dir
            else
                set -gx SCROLLBACK_HISTORY_DIR "$HOME/.terminal_history"
            end
        case __fish_scrollback_history_max_files
            if set -q __fish_scrollback_history_max_files
                set -gx SCROLLBACK_HISTORY_MAX_FILES $__fish_scrollback_history_max_files
            else
                set -gx SCROLLBACK_HISTORY_MAX_FILES 100
            end
    end
end
