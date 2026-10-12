# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_key_info KEY
#
# DESCRIPTION
#   Finds which template owns setting KEY and prints
#   TEMPLATE<TAB>KEY<TAB>TYPE<TAB>REQUIRED<TAB>PROMPT.
#
# EXIT STATUS
#   0  Found
#   1  No template has this setting
function __fish_template_key_info --argument-names key --description 'Describe a fish-template setting'
    for t in (__fish_template_names)
        for row in (__fish_template_settings (__fish_template_file $t))
            if test (string split -f1 \t -- $row) = "$key"
                printf '%s\t%s\n' $t $row
                return 0
            end
        end
    end
    return 1
end
