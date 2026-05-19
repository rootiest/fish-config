# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Print colored installed/missing status for all deps, grouped by tier.
function _fish_deps_status
    _fish_deps_catalog

    function __fds_print_dep --argument-names bin tier
        if type -q $bin
            set_color green; echo -n " ✓ "; set_color normal
            echo -n "$bin "
            set_color brblack; echo "(Found at "(type -p $bin)")"; set_color normal
        else if test "$tier" = rec
            set_color yellow; echo -n " ⚠ "; set_color normal
            echo -n "$bin "
            set_color brblack; echo "(Not installed)"; set_color normal
        else
            set_color red; echo -n " ✗ "; set_color normal
            echo -n "$bin "
            set_color brblack; echo "(Not installed)"; set_color normal
        end
    end

    for tier_label in "Required Dependencies:req" "Integrations:int" "Recommended Dependencies:rec"
        set -l label (string split : $tier_label)[1]
        set -l tier  (string split : $tier_label)[2]
        set_color cyan; echo $label; set_color normal
        set -l i 1
        for bin in $_fdc_bins
            if test "$_fdc_tiers[$i]" = $tier
                __fds_print_dep $bin $tier
            end
            set i (math $i + 1)
        end
        echo ""
    end

    functions -e __fds_print_dep
end
