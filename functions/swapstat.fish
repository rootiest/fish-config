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
# EXAMPLE
#   swapstat
function swapstat --description 'View colorized zRAM and swappiness status'
    set -l swappiness (sysctl -n vm.swappiness)
    set -l zdata (zramctl --bytes --noheadings --output DATA,TOTAL /dev/zram0 2>/dev/null)
    
    echo (set_color --bold blue)"── Memory & zRAM Report ──"(set_color normal)
    
    # Kernel & Compression Stats
    if test -n "$zdata"
        set -l raw (echo $zdata | awk '{print $1}')
        set -l compressed (echo $zdata | awk '{print $2}')
        if test "$compressed" -gt 0
            set -l ratio (math -s2 "$raw / $compressed")
            echo (set_color yellow)"Compression Ratio: "(set_color normal)"$ratio:1"
        end
    end
    echo (set_color yellow)"Kernel Swappiness: "(set_color normal)"$swappiness"
    echo ""

    # Colorized zRAM Table
    # Colors the header green and the device path (/dev/...) cyan
    echo (set_color --bold --underline magenta)"zRAM Device Details"(set_color normal)
    zramctl --output NAME,ALGORITHM,DISKSIZE,DATA,COMPR,TOTAL,STREAMS | sed \
        -e "1s/.*/$(set_color --bold green)&$(set_color normal)/" \
        -e "s|/dev/zram[0-9]|$(set_color cyan)&$(set_color normal)|"

    echo ""

    # Colorized Swapon Table
    # Colors the header green and the device path cyan
    echo (set_color --bold --underline magenta)"Active Swap Priority"(set_color normal)
    swapon --show | sed \
        -e "1s/.*/$(set_color --bold green)&$(set_color normal)/" \
        -e "s|/dev/[^ ]*|$(set_color cyan)&$(set_color normal)|"
end
