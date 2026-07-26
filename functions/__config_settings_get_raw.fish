# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_get_raw <varname>
#
# DESCRIPTION
#   Prints the current value of a universal variable for display in the
#   config-settings value pages. List variables are printed space-joined.
#   Prints "DEFAULT" when the variable is unset in every scope.
#
# ARGUMENTS
#   varname  Variable name without the $ prefix
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The value, or "DEFAULT" if unset, printed to stdout
#
# EXAMPLE
#   set v (__config_settings_get_raw sponge_delay)   # "2" or "DEFAULT"
function __config_settings_get_raw
    set -l varname $argv[1]
    if set -q $varname
        string join ' ' -- $$varname
    else
        echo DEFAULT
    end
end
