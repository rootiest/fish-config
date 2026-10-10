# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_status
#
# DESCRIPTION
#   Prints a colored installed/missing status report for all managed fish shell
#   dependencies, grouped by tier (required, recommended, optional, terminal
#   emulators, integrations).
#
# EXAMPLE
#   _fish_deps_status
function _fish_deps_status
    _fish_deps_catalog

    function __fds_print_dep --argument-names bin tier
        # command -q (not type -q): probe PATH only, so wrapper functions that
        # shadow a tool name (rg, rm, yt-dlp) don't mask a missing binary.
        if command -q $bin
            # Special version check: fish < 4.0 is functionally incompatible
            if test "$bin" = fish
                set -l _major (fish --version 2>&1 | string match -r 'version (\d+)')[2]
                if test -n "$_major"; and test "$_major" -lt 4
                    set -l _ver (fish --version 2>&1 | string replace 'fish, ' '')
                    echo -n (__fish_color yellow)
                    echo -n " ⚠ "
                    echo -n (__fish_color normal)
                    echo -n "$bin "
                    echo -n (__fish_color brblack)
                    echo "($_ver — upgrade to 4.0+ required)"
                    echo -n (__fish_color normal)
                    return
                end
            end
            echo -n (__fish_color green)
            echo -n " ✓ "
            echo -n (__fish_color normal)
            echo -n "$bin "
            echo -n (__fish_color brblack)
            echo "(Found at "(__fish_real_command $bin)")"
            echo -n (__fish_color normal)
        else if contains -- $bin paru yay; and not _fish_deps_is_arch
            # AUR helpers do not exist off Arch: not a gap, so no warning.
            echo -n (__fish_color brblack)
            echo " – $bin (Arch only — not applicable on this system)"
            echo -n (__fish_color normal)
        else if test "$tier" = req
            echo -n (__fish_color red)
            echo -n " ✗ "
            echo -n (__fish_color normal)
            echo -n "$bin "
            echo -n (__fish_color brblack)
            echo "(Not installed)"
            echo -n (__fish_color normal)
        else if test "$tier" = rec
            echo -n (__fish_color yellow)
            echo -n " ⚠ "
            echo -n (__fish_color normal)
            echo -n "$bin "
            echo -n (__fish_color brblack)
            echo "(Not installed)"
            echo -n (__fish_color normal)
        else
            # opt / term / int: absence is expected and not alarming
            echo -n (__fish_color brblack)
            echo -n " – "
            echo -n (__fish_color normal)
            echo -n "$bin "
            echo -n (__fish_color brblack)
            echo "(Not installed)"
            echo -n (__fish_color normal)
        end
    end

    for tier_label in "Required Dependencies:req" "Recommended Dependencies:rec" "Optional Dependencies:opt" "Terminal Emulators:term" "Integrations:int"
        set -l label (string split : $tier_label)[1]
        set -l tier (string split : $tier_label)[2]
        echo -n (__fish_color cyan)
        echo $label
        echo -n (__fish_color normal)
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
