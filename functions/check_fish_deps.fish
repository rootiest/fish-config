# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function check_fish_deps --description "Check all fish-related dependencies"
    set -l required fish fisher starship fzf zoxide direnv paru
    set -l integrations wakatime tailscale
    set -l recommended eza lsd bat btop dust duf prettyping most rg lazygit lazydocker trash kitty wezterm

    function __print_dep
        set -l dep $argv[1]
        if type -q $dep
            set_color green
            echo -n "   "
            set_color normal
            echo -n "$dep "
            set_color brblack
            echo "(Found at "(type -p $dep)")"
            set_color normal
        else
            set_color red
            echo -n "   "
            set_color normal
            echo -n "$dep "
            set_color brblack
            echo "(Not installed)"
            set_color normal
        end
    end

    set_color cyan; echo "Required Dependencies:"; set_color normal
    for dep in $required
        __print_dep $dep
    end
    echo ""

    set_color cyan; echo "Integrations:"; set_color normal
    for dep in $integrations
        __print_dep $dep
    end
    echo ""

    set_color cyan; echo "Recommended Dependencies:"; set_color normal
    for dep in $recommended
        __print_dep $dep
    end
    echo ""
    
    functions -e __print_dep
end
