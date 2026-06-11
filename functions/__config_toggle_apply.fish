# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_toggle_apply <varname> <scope> <value>
#
# DESCRIPTION
#   Applies a state value to an opinionated-component variable in the given
#   scope, immediately and persistently. Used by config-toggle's Left/Right
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
#   value    "on", "off", or "DEFAULT"
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   __config_toggle_apply __fish_config_op_aliases universal off
#   __config_toggle_apply __fish_config_op_greeting session DEFAULT
function __config_toggle_apply
    set -l varname $argv[1]
    set -l scope   $argv[2]
    set -l value   $argv[3]

    switch $scope
        case universal
            switch $value
                case on
                    set -U $varname on
                case off
                    set -U $varname off
                case DEFAULT
                    set -Ue $varname
            end
        case session
            switch $value
                case on
                    set -g $varname on
                case off
                    set -g $varname off
                case DEFAULT
                    set -eg $varname
            end
    end
end
