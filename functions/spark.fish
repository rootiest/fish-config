# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   13-media-and-utilities
#
# SYNOPSIS
#   spark [--min=<n>] [--max=<n>] [numbers...]
#
# DESCRIPTION
#   Renders a Unicode sparkline bar chart for a sequence of numbers.
#   Reads numbers from arguments or from stdin if none are provided.
#   Optional --min and --max clamp the scale range.
#
# ARGUMENTS
#   --min=<n>   Minimum value for scale (default: list minimum)
#   --max=<n>   Maximum value for scale (default: list maximum)
#   numbers...  Space-separated numbers to chart; reads stdin if omitted
#   -v, --version  Print version
#   -h, --help     Show usage help
#
# EXAMPLE
#   spark 1 1 2 5 14 42
#   seq 64 | sort --random-sort | spark
#   echo "3 7 2 9 1" | spark
function spark --description 'Sparklines'
    argparse --ignore-unknown --name=spark v/version h/help m/min= M/max= -- $argv || return

    if set --query _flag_version[1]
        echo "spark, version 1.1.0"
    else if set --query _flag_help[1]
        set -l c_head (set_color --bold cyan)
        set -l c_cmd (set_color --bold)
        set -l c_flag (set_color yellow)
        set -l c_arg (set_color cyan)
        set -l c_reset (set_color normal)
        echo "$c_head""Usage:$c_reset $c_cmd""spark$c_reset $c_arg""<numbers ...>$c_reset"
        echo "       stdin | $c_cmd""spark$c_reset"
        echo "$c_head""Options:$c_reset"
        echo "       $c_flag--min$c_reset""=$c_arg<number>$c_reset   Minimum range"
        echo "       $c_flag--max$c_reset""=$c_arg<number>$c_reset   Maximum range"
        echo "       $c_flag-v$c_reset or $c_flag--version$c_reset  Print version"
        echo "       $c_flag-h$c_reset or $c_flag--help$c_reset     Print this help message"
        echo "$c_head""Examples:$c_reset"
        echo "       $c_cmd""spark$c_reset 1 1 2 5 14 42"
        echo "       seq 64 | sort --random-sort | $c_cmd""spark$c_reset"
    else if set --query argv[1]
        printf "%s\n" $argv | spark --min="$_flag_min" --max="$_flag_max"
    else
        command awk -v min="$_flag_min" -v max="$_flag_max" '
            {
                m = min == "" ? m == "" ? $0 : m > $0 ? $0 : m : min
                M = max == "" ? M == "" ? $0 : M < $0 ? $0 : M : max
                nums[NR] = $0
            }
            END {
                n = split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", sparks, " ") - 1
                while (++i <= NR) 
                    printf("%s", sparks[(M == m) ? 3 : sprintf("%.f", (1 + (nums[i] - m) * n / (M - m)))])
            }
        ' && echo
    end
end
