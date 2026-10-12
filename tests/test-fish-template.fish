#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for fish-template and its helpers, and for the user-dots
# functions/ startup snippet (conf.d/user-dots-functions.fish,
# __fish_user_dots_dir). Template behavior itself is covered by
# tests/test-templates.fish.

source (realpath (dirname (status filename)))/lib.fish

# Run SCRIPT in a fresh --no-config fish with the repo functions on the
# path and DIR/bin first on PATH. stdin is inherited so callers can pipe
# wizard answers in; stderr is merged into stdout.
function _ft --argument-names dir script
    env TERM=dumb PATH="$dir/bin:$PATH" fish --no-config -c "set -g fish_function_path $repo_root/functions \$fish_function_path
        $script" 2>&1
end

section "startup: user-dots functions/"
set -l tmp (mktemp -d)
set -l out (_ft $tmp "set -g __fish_user_dots_path $tmp/dots
    source $repo_root/conf.d/user-dots-functions.fish
    contains -- $tmp/dots/functions \$fish_function_path; and echo added; or echo absent")
check "a missing directory is not added" absent "$out"

mkdir -p $tmp/dots/functions
set -l out (_ft $tmp "set -g __fish_user_dots_path $tmp/dots
    source $repo_root/conf.d/user-dots-functions.fish
    source $repo_root/conf.d/user-dots-functions.fish
    echo \$fish_function_path[1] (count (string match -- $tmp/dots/functions \$fish_function_path))")
check "an existing directory is prepended, once" "$tmp/dots/functions 1" "$out"

printf '%s\n' 'function ud_probe' '    echo from-user-dots' end >$tmp/dots/functions/ud_probe.fish
set -l out (_ft $tmp "set -g __fish_user_dots_path $tmp/dots
    source $repo_root/conf.d/user-dots-functions.fish
    ud_probe")
check "functions in it autoload" from-user-dots "$out"

# A fresh HOME/XDG keeps any universal __fish_user_dots_path out of it.
set -l out (env XDG_CONFIG_HOME=$tmp/xdg HOME=$tmp fish --no-config -c \
    "set -g fish_function_path $repo_root/functions \$fish_function_path; __fish_user_dots_dir")
check "default path follows XDG_CONFIG_HOME" $tmp/xdg/.user-dots/fish "$out"
set -l out (env -u XDG_CONFIG_HOME HOME=$tmp/h fish --no-config -c \
    "set -g fish_function_path $repo_root/functions \$fish_function_path; __fish_user_dots_dir")
check "falls back to ~/.config without XDG_CONFIG_HOME" $tmp/h/.config/.user-dots/fish "$out"
rm -rf $tmp

report
