# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

complete -c rand_string -f

complete -c rand_string -s s -l separator -x -a 'dash underscore dot none' -d 'Set separator for following words'
complete -c rand_string -s c -l case -x -a 'lower upper title' -d 'Set casing for following words'
complete -c rand_string -s h -l help -d 'Show usage help'

# List of all available lists in data/words
set -l categories
if set -q __fish_config_dir
    set categories (string replace -r '\.txt$' '' (command ls $__fish_config_dir/data/words/*.txt 2>/dev/null | command xargs -n 1 basename 2>/dev/null))
end

for cat in $categories
    complete -c rand_string -a "$cat" -d "Pick a random word from the $cat list"
end

complete -c rand_string -a 'digits=' -d 'Generate N random digits (e.g. digits=3)'
complete -c rand_string -a 'literal=' -d 'Insert a literal string exactly as provided'
