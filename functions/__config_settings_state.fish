# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   __config_settings_get_val, __config_settings_get_raw,
#   __config_settings_subcats
#
# SYNOPSIS
#   __config_settings_state
#
# DESCRIPTION
#   Dumps everything scripts/config-settings-tui.py needs to render the
#   settings TUI: the current value of every opinionated-component,
#   sponge, scrollback and user-dots variable, plus the sub-category
#   taxonomy from __config_settings_subcats.
#
#   Two record types, separated by RS (0x1e), fields separated by US
#   (0x1f). Both are ASCII control characters, so no value these variables
#   can hold needs escaping on the way through:
#
#     var<US><scope><US><name><US><value>
#     sub<US><category_var><US><slug><US><label><US><description>
#
#   Only variables that are actually set are emitted; the TUI renders an
#   absent variable as DEFAULT. That is what keeps the variable list out of
#   this function -- names are discovered with `set --names` and filtered by
#   prefix, so a new sub-category needs no edit here, only in
#   __config_settings_subcats.
#
#   Toggle variables are dumped once per scope (universal and session), since
#   the TUI edits those scopes independently. Sponge and Paths variables are
#   universal-only and dumped as the value the running shell resolves,
#   space-joined for list variables.
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The RS/US-separated state dump, printed to stdout
#
# EXAMPLE
#   __config_settings_state | string split \x1e
function __config_settings_state --description 'Dump config-settings state for the curses TUI'
    # ── Variable values ───────────────────────────────────────────────────
    for name in (set --names)
        switch $name
            case '__fish_config_op_registry_*'
                # conf.d data table, not a setting -- shares the op_ prefix.
                continue
            case '__fish_config_op_*' __fish_config_opinionated
                # Toggles: both scopes, independently editable.
                for scope in universal session
                    set -l val (__config_settings_get_val $name $scope)
                    test "$val" = DEFAULT; and continue
                    printf '%s\x1f%s\x1f%s\x1f%s\x1e' var $scope $name $val
                end
            case 'sponge_*' __fish_sponge_extra_sensitive \
                '__fish_scrollback_history_*' __fish_user_dots_path \
                __fish_user_dots_symlink
                # Value rows: universal-only, list variables space-joined.
                set -l val (__config_settings_get_raw $name)
                test "$val" = DEFAULT; and continue
                printf '%s\x1f%s\x1f%s\x1f%s\x1e' var universal $name $val
        end
    end

    # ── Sub-category taxonomy ─────────────────────────────────────────────
    for cvar in __fish_config_op_aliases __fish_config_op_autoexec \
        __fish_config_op_overrides __fish_config_op_integrations \
        __fish_config_op_logging __fish_config_op_greeting
        for row in (__config_settings_subcats $cvar)
            set -l f (string split -- \t $row)
            printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1e' sub $cvar $f[1] $f[2] $f[3]
        end
    end
end
