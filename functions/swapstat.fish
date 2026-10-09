# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# SYNOPSIS
#   swapstat
#
# DESCRIPTION
#   Displays a colorized memory report showing kernel swappiness,
#   zRAM compression ratio, zRAM device details (via zramctl), and
#   active swap priority (via swapon).
#
# EXIT STATUS
#   0  Report shown
#   2  Unexpected argument (takes none)
#
# EXAMPLE
#   swapstat
function swapstat --description 'View colorized zRAM and swappiness status'
    __fish_help_header (status current-function) $argv; and return 0
    __fish_no_args (status current-function) $argv; or return

    set -l swappiness (sysctl -n vm.swappiness)
    set -l zdata (zramctl --bytes --noheadings --output DATA,TOTAL /dev/zram0 2>/dev/null)

    echo (__fish_color --bold blue)"── Memory & zRAM Report ──"(__fish_color normal)

    # Kernel & Compression Stats
    if test -n "$zdata"
        set -l raw (echo $zdata | awk '{print $1}')
        set -l compressed (echo $zdata | awk '{print $2}')
        if test "$compressed" -gt 0
            set -l ratio (math -s2 "$raw / $compressed")
            echo (__fish_color yellow)"Compression Ratio: "(__fish_color normal)"$ratio:1"
        end
    end
    echo (__fish_color yellow)"Kernel Swappiness: "(__fish_color normal)"$swappiness"
    echo ""

    # Colorized zRAM Table
    # Colors the header green and the device path (/dev/...) cyan
    echo (__fish_color --bold --underline magenta)"zRAM Device Details"(__fish_color normal)
    zramctl --output NAME,ALGORITHM,DISKSIZE,DATA,COMPR,TOTAL,STREAMS | sed \
        -e "1s/.*/$(__fish_color --bold green)&$(__fish_color normal)/" \
        -e "s|/dev/zram[0-9]|$(__fish_color cyan)&$(__fish_color normal)|"

    echo ""

    # Colorized Swapon Table
    # Colors the header green and the device path cyan
    echo (__fish_color --bold --underline magenta)"Active Swap Priority"(__fish_color normal)
    swapon --show | sed \
        -e "1s/.*/$(__fish_color --bold green)&$(__fish_color normal)/" \
        -e "s|/dev/[^ ]*|$(__fish_color cyan)&$(__fish_color normal)|"
end
