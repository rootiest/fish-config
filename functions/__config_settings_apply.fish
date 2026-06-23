# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_apply <varname> <scope> <value>
#
# DESCRIPTION
#   Applies a state value to an opinionated-component variable in the given
#   scope, immediately and persistently. Used by config-settings's Left/Right
#   (and vim h/l) directional handlers so the set/erase logic lives in one
#   place. A value of "DEFAULT" erases the variable in that scope so the
#   master switch / built-in default takes over again.
#
#     universal → set -U  (on/off)  /  set -Ue  (DEFAULT)
#     session   → set -g  (on/off)  /  set -eg  (DEFAULT)
#
# ARGUMENTS
#   varname  Variable name without the $ prefix
#   scope    "universal" or "session"
#   value    "on", "off", "DEFAULT", or any arbitrary string (universal scope only)
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   __config_settings_apply __fish_config_op_aliases universal off
#   __config_settings_apply __fish_config_op_greeting session DEFAULT
function __config_settings_apply
    set -l varname $argv[1]
    set -l scope   $argv[2]
    set -l value   $argv[3]

    # stderr is suppressed because setting a value in one scope while the
    # other scope already holds the same variable makes interactive fish
    # emit a shadowing warning ("set: successfully set universal 'X'; but a
    # global by that name shadows it"). config-settings intentionally edits
    # both scopes independently, so the warning is expected noise — and if
    # it reached the terminal it would push the cursor down a row and
    # corrupt the in-place panel redraw (leaving a stacked top border
    # behind). Note: the warning only fires in a real interactive TTY, not
    # under `fish -ic`, which is why it is easy to miss when testing.
    switch $scope
        case universal
            switch $value
                case on
                    set -U $varname on 2>/dev/null
                case off
                    set -U $varname off 2>/dev/null
                case DEFAULT
                    set -Ue $varname 2>/dev/null
                case '*'
                    set -U $varname $value 2>/dev/null
            end
        case session
            switch $value
                case on
                    set -g $varname on 2>/dev/null
                case off
                    set -g $varname off 2>/dev/null
                case DEFAULT
                    set -eg $varname 2>/dev/null
            end
    end
end
