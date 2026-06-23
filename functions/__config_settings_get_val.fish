# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_get_val <varname> <scope>
#
# DESCRIPTION
#   Returns the current value of a named variable in the specified scope by
#   parsing `set --show` output. Outputs "on", "off", or "DEFAULT" (when
#   the variable is not set in that scope). Scope "session" maps to "global"
#   in fish's internal terminology.
#
# ARGUMENTS
#   varname  Variable name without $ prefix
#   scope    "universal" or "session"
#
# RETURNS
#   0  Always; prints "on", "off", or "DEFAULT" to stdout
#
# EXAMPLE
#   set result (__config_settings_get_val __fish_config_op_aliases universal)
#   # result == "on" | "off" | "DEFAULT"
function __config_settings_get_val
    set -l varname $argv[1]
    set -l scope $argv[2]

    set -l scope_kw $scope
    if test $scope = session
        set scope_kw global
    end

    set -l found 0
    for line in (set --show $varname 2>/dev/null)
        if string match -q "*$scope_kw scope*" $line
            set found 1
            continue
        end
        if test $found -eq 1
            set found 0
            set -l val (string replace -r '^\$[^\[]+\[1\]: \|(.+)\|$' '$1' $line 2>/dev/null)
            if test -n "$val" -a "$val" != $line
                echo $val
                return 0
            end
        end
    end

    echo DEFAULT
    return 0
end
