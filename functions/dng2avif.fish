# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function dng2avif --description 'Convert DNG raw to 10-bit HDR AVIF'
    set -l options (fish_opt -s h -l help)
    set -a options (fish_opt -s i -l input -r)
    set -a options (fish_opt -s o -l output -r)
    set -a options (fish_opt -s q -l quality -r)
    set -a options (fish_opt -s s -l speed -r)

    argparse $options -- $argv
    or return

    # Help Screen
    if set -q _flag_help; or test (count $argv) -eq 0 -a -z "$_flag_input"
        echo "Usage: dng2avif [options] [input.dng]"
        echo ""
        echo "Options:"
        echo "  -i, --input FILE    Input DNG file"
        echo "  -o, --output FILE   Output AVIF file (defaults to input name)"
        echo "  -q, --quality N     Encoding quality 0-100 (default: 92)"
        echo "  -s, --speed N       Encoder speed 0-10 (default: 3, 0=slowest)"
        echo "  -h, --help          Show this help message"
        return 0
    end

    # Handle Input Source
    set -l input ""
    if set -q _flag_input
        set input $_flag_input
    else
        set input $argv[1]
    end

    if not test -f "$input"
        echo (set_color red)"Error: File '$input' not found."(set_color normal)
        return 1
    end

    # Configuration
    set -l quality 92
    if set -q _flag_quality
        set quality $_flag_quality
    end

    set -l speed 3
    if set -q _flag_speed
        set speed $_flag_speed
    end

    set -l basename (string replace -r '\.dng$' '' $input)
    set -l output "$basename.avif"
    if set -q _flag_output
        set output $_flag_output
    end

    set -l temp_pnm "$basename"_temp.pnm

    # Dependency check
    for cmd in magick ffmpeg avifenc exiftool
        if not type -q $cmd
            echo (set_color red)"Error: $cmd is not installed."(set_color normal)
            return 1
        end
    end

    # Step 1: Develop
    echo -n (set_color blue)"Step 1/3: Developing... "(set_color normal)
    magick "$input" -depth 16 pnm:"$temp_pnm" &>/dev/null
    if test $status -ne 0
        echo (set_color red)"FAILED"
        return 1
    end
    echo (set_color green)"DONE"(set_color normal)

    # Step 2: Encode
    echo -n (set_color blue)"Step 2/3: Encoding (Q:$quality, S:$speed)... "(set_color normal)
    ffmpeg -i "$temp_pnm" -vf "format=yuv444p10le" -f yuv4mpegpipe -strict -1 - 2>/dev/null | avifenc -q $quality -s $speed --stdin -d 10 -y 444 --cicp 12/1/1 -r f -o "$output" &>/dev/null
    if test $status -ne 0
        echo (set_color red)"FAILED"
        rm -f "$temp_pnm"
        return 1
    end
    echo (set_color green)"DONE"(set_color normal)

    # Step 3: Metadata
    echo -n (set_color blue)"Step 3/3: Syncing Metadata... "(set_color normal)
    exiftool -tagsFromFile "$input" -all:all "$output" -overwrite_original &>/dev/null
    if test $status -ne 0
        echo (set_color red)"FAILED"
    else
        echo (set_color green)"DONE"(set_color normal)
    end

    # Final Cleanup
    test -f "$temp_pnm"; and rm "$temp_pnm"

    set -l size (stat -c '%s' "$output" | numfmt --to=iec)
    echo (set_color yellow)"Complete: $output ($size)"(set_color normal)
end
