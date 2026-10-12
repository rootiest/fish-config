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

section "helpers: value store"
set -l tmp (mktemp -d)
set -l out (_ft $tmp "__fish_template_store set k 'a b' '' '\$HOME' '(echo X)' \"it's\" -x
    __fish_template_store emit k >$tmp/r.fish
    __fish_template_store reset
    __fish_template_store has k; and echo leaked
    __fish_template_store load $tmp/r.fish
    printf '[%s]' (__fish_template_store get k)")
check "values survive emit, reset and load exactly" "[a b][][\$HOME][(echo X)][it's][-x]" "$out"

printf '%s\n' "set -l k (touch $tmp/canary) \$HOME" "touch $tmp/canary2" >$tmp/evil.fish
set -l out (_ft $tmp "__fish_template_store load --mark $tmp/evil.fish
    printf '[%s]' (__fish_template_store get k)
    __fish_template_store marked k; and echo ' marked'")
check "load keeps literals and marks with --mark" "[(touch $tmp/canary)][\$HOME] marked" "$out"
check "load never runs anything" "no no" "$(test -e $tmp/canary; and echo yes; or echo no) $(test -e $tmp/canary2; and echo yes; or echo no)"

printf '%s\n' 'set -l k old' >$tmp/d.fish
set -l out (_ft $tmp "__fish_template_store set k new
    __fish_template_store load --defaults $tmp/d.fish
    __fish_template_store get k")
check "load --defaults never overrides a value" new "$out"

section "helpers: template parsing"
mkdir -p $tmp/tpl/targets $tmp/tpl/modifiers $tmp/tpl/presets
printf '%s\n' '# TEMPLATE  demo' '# KIND      modifier' '# PHASE     prepare' '# ORDER     5' \
    '# APPLIES   command' '# SUMMARY   Demo' '# PHRASE    with {demo_n} things' '' \
    '#   ── Settings ──' '' '# How many. (int, required)' 'set -l demo_n 3' \
    '# Mode to use. (choice: a b)' 'set -l demo_mode a' '# Free text.' "set -l demo_text 'x y'" '' \
    '#   ── Fragment ──' '' 'set -l __ft_not_a_setting 1' 'set __ft_attempts $demo_n' '' \
    '#   ── Fragment: finally ──' 'echo done' >$tmp/tpl/modifiers/demo.fish
set -l pre "set -g __fish_template_root $tmp/tpl"
set -l f $tmp/tpl/modifiers/demo.fish

set -l out (_ft $tmp "$pre; __fish_template_settings $f")
check "settings: int + required" (printf 'demo_n\tint\t1\tHow many.') "$out[1]"
check "settings: choice" (printf 'demo_mode\tchoice:a b\t0\tMode to use.') "$out[2]"
check "settings: untyped is text; fragment set -l lines are not settings" (printf 'demo_text\ttext\t0\tFree text.') "$out[3..]"

set -l out (_ft $tmp "$pre; __fish_template_fragment $f prepare")
check "fragment: bare banner uses PHASE" "set -l __ft_not_a_setting 1 set __ft_attempts \$demo_n" "$out"
set -l out (_ft $tmp "$pre; __fish_template_fragment $f finally")
check "fragment: named banner" "echo done" "$out"
set -l out (_ft $tmp "$pre; __fish_template_fragment $f guard; echo st=\$status")
check "fragment: absent phase is status 1" st=1 "$out"

set -l out (_ft $tmp "$pre; __fish_template_meta $f ORDER; __fish_template_meta $f NOPE; echo st=\$status")
check "meta: value, and status 1 when absent" "5 st=1" "$out"
set -l out (_ft $tmp "$pre; __fish_template_names modifier; __fish_template_file demo; __fish_template_file ../demo; echo st=\$status; __fish_template_dir")
check "names, file lookup, traversal refused, dir override" "demo $f st=1 $tmp/tpl" "$out"

set -l out (_ft $tmp "$pre; __fish_template_key_info demo_mode; __fish_template_key_info nope; echo st=\$status")
check "key_info: owner and type; unknown is 1" (printf 'demo\tdemo_mode\tchoice:a b\t0\tMode to use.')" st=1" "$out"

section "helpers: setting checks"
set -l out (_ft $tmp "set -gx HOME /h
    __fish_template_check k path 0 '~/x'
    __fish_template_check k bool 0 Yes
    __fish_template_check k list 0 a b
    __fish_template_check k int 0 42")
check "normalizes path, bool, list, int" "/h/x true a b 42" "$out"
for case in "int 0 abc" "choice:a\\ b 0 c" "list 1" "text 0 a b" "bool 0 maybe" "text 1 ''"
    set -l out (_ft $tmp "__fish_template_check k $case >/dev/null; echo st=\$status")
    check "rejects: $case" "st=1" "$out[-1]"
end
rm -rf $tmp

report
