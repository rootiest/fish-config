# # Copyright (C) 2026 Rootiest
# # SPDX-License-Identifier: AGPL-3.0-or-later
#
# # Placeholder for a future implementation of a "fast" function
# function fast --description 'Placeholder for future fast utility'
#     # Defining Catppuccin Mocha colors
#     set -l flamingo F2CDCD
#     set -l blue 89B4FA
#     set -l mauve cba6f7
#     set -l mantle 181825
#
#     echo -e ""
#     echo -n (set_color $flamingo)" 󰊠 "(set_color --bold)"The '"
#     echo -n (set_color $mauve)"fast"
#     echo -n (set_color $flamingo)"' command is not currently available."
#     echo -e ""
#     echo -n (set_color $blue)"   Did you mean: "
#     echo -n (set_color --bold $mauve)"fast-cli"
#     echo -n (set_color --italics $blue)"?"(set_color normal)
#     echo -e "\n"
# end

# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Placeholder for a future implementation of a "fast" function
function fast --description 'Placeholder for future fast utility'
    # ANSI Escape Codes (Standard 16-color palette)
    set -l bold "\e[1m"
    set -l italic "\e[3m"
    set -l red "\e[31m"
    set -l blue "\e[34m"
    set -l yellow "\e[33m"
    set -l magenta "\e[35m"
    set -l reset "\e[0m"

    # Using printf for reliable ANSI rendering
    printf " %b  %bThe command:   %b%bfast%b%b   is currently unavailable.%b\n" "$yellow" "$bold" "$reset" "$magenta" "$reset" "$yellow" "$reset"
    printf "    %bDid you mean: %b%bfast-cli%b%b?%b\n" "$blue" "$reset" "$bold$magenta" "$reset" "$italic$blue" "$reset"
    printf "\n"
end
