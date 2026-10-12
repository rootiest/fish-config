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

section "helpers: store load markers"
set -l tmp (mktemp -d)
printf '%s\n' 'set -l a 1' 'function demo' '    # ── fish-template recipe ──' "    set -l b 'x  y' ~/z" \
    '    # ── end recipe ──' end 'set -l c 3' >$tmp/gen.fish
set -l out (_ft $tmp "__fish_template_store load $tmp/gen.fish
    printf '[%s]' (__fish_template_store get b)
    __fish_template_store has a; and echo ' a-set'
    __fish_template_store has c; and echo ' c-set'")
check "load reads only the recipe block, literally, indented" "[x  y][~/z]" "$out"

printf '%s\n' 'set -l t 1' '#   ── Fragment ──' 'set -l u 2' >$tmp/tpl.fish
set -l out (_ft $tmp "__fish_template_store load $tmp/tpl.fish
    __fish_template_store has t; and echo t-set
    __fish_template_store has u; and echo u-set")
check "load stops at the Fragment banner" t-set "$out"
rm -rf $tmp

section "helpers: validate"
set -l tmp (mktemp -d)
# Each row: expected stderr fragment, then the recipe setup.
for row in "no target chosen|set __ft_use" \
    "unknown target|set __ft_use nope" \
    "a value is required|set __ft_use command; __fish_template_store set retry_attempts 3" \
    "a value is required|set __ft_use command" \
    "cannot be used with a sequence target|set __ft_use sequence timeout; __fish_template_store set sequence_steps true" \
    "env_unset needs a command or fallback target|set __ft_use sequence env; __fish_template_store set sequence_steps true; __fish_template_store set env_unset X" \
    "retry_attempts: expects a whole number|set __ft_use command retry; __fish_template_store set command_cmd x; __fish_template_store set retry_attempts many" \
    "is listed twice|set __ft_use command retry retry; __fish_template_store set command_cmd x"
    set -l want (string split -m1 '|' -- $row)
    set -l out (_ft $tmp "__fish_template_store $want[2]; __fish_template_validate 2>&1 >/dev/null; echo st=\$status")
    check "rejected with 2: $want[2]" st=2 "$out[-1]"
    check "  and says: $want[1]" yes (string match -q -- "*$want[1]*" "$out"; and echo yes; or echo no)
end
set -l out (_ft $tmp "__fish_template_store set __ft_use command
    __fish_template_store set command_cmd x
    __fish_template_store set bogus_key 1
    __fish_template_validate; echo st=\$status; __fish_template_store has bogus_key; or echo dropped")
check "unknown keys are dropped with a warning" "fish-template: ignoring unknown setting bogus_key st=0 dropped" "$out"

section "helpers: assemble"
set -l out (_ft $tmp "__fish_template_store set __ft_use command
    __fish_template_store set command_cmd probe
    __fish_template_validate; and __fish_template_assemble my-fn >$tmp/my-fn.fish
    fish -n $tmp/my-fn.fish; and echo syntax-ok
    fish_indent --check <$tmp/my-fn.fish; and echo indent-ok
    string match -qr '^\s*function \\\$' <$tmp/my-fn.fish; or echo no-dollar-function
    string match -q 'function my-fn *' <$tmp/my-fn.fish; and echo literal-name
    __fish_template_store load $tmp/my-fn.fish; __fish_template_store get command_cmd")
check "generated file: valid, formatted, literal name, recipe readable" "syntax-ok indent-ok no-dollar-function literal-name probe" "$out"
rm -rf $tmp
section "cli: new, safety and output"
set -l tmp (mktemp -d)
mkdir -p $tmp/bin
printf '#!/bin/sh\necho "args=$*"; exit 7\n' >$tmp/bin/probe
chmod +x $tmp/bin/probe
set -l o "--output $tmp/out"
set -l out (_ft $tmp "fish-template new pw --target command --set command_cmd=probe --with retry --set retry_delay=0 --yes $o
    echo st=\$status; pw a; echo st=\$status")
check "writes, loads and runs immediately" yes (string match -q -- '*pw is ready*st=0*args=a*st=7' "$out"; and echo yes; or echo no)
set -l before (cat $tmp/out/pw.fish | string collect)
set -l out (_ft $tmp "fish-template new pw --target command --set command_cmd=other --yes $o; echo st=\$status")
check "refuses to overwrite without --force" yes (string match -q -- '*already exists*st=1' "$out"; and test "$before" = "$(cat $tmp/out/pw.fish | string collect)"; and echo yes; or echo no)
set -l out (_ft $tmp "fish-template new pw --target command --set command_cmd=other --yes --force $o; echo st=\$status")
check "--force replaces it" st=0 "$out[-1]"
set -l out (_ft $tmp "fish-template new dry --target command --set command_cmd=probe --yes --dry-run $o; echo st=\$status")
check "--dry-run prints and writes nothing" yes (string match -q -- '*function dry *st=0' "$out"; and not test -e $tmp/out/dry.fish; and echo yes; or echo no)
set -l out (_ft $tmp "fish-template new printf --target command --set command_cmd=probe --yes $o 2>&1")
check "warns when shadowing a builtin" yes (string match -q -- '*shadows the fish builtin printf*' "$out"; and echo yes; or echo no)
set -l out (_ft $tmp "fish-template new probe --target command --set command_cmd=probe --yes $o 2>&1")
check "notes a same-name wrapper instead of warning" yes (string match -q -- '*wraps the probe command*' "$out"; and echo yes; or echo no)
for case in "new -x --target command --set command_cmd=a --yes" \
    "new a --target nope --yes" \
    "new a --target sequence --with timeout --set 'sequence_steps=true' --yes" \
    "new a --target command --set bogus=1 --yes" \
    "new a --target command --set command_cmd=a --set retry_attempts=abc --with retry --yes" \
    "new a --target command --yes" \
    "new --target command --set command_cmd=a --yes" \
    "new a --from x --preset safe-rm --yes"
    set -l out (_ft $tmp "fish-template $case $o >/dev/null 2>&1; echo st=\$status")
    check "usage error 2: $case" st=2 "$out[-1]"
end

for w in set end
    set -l out (_ft $tmp "fish-template new $w --target command --set command_cmd=probe --yes $o; echo st=\$status")
    check "reserved word $w: exit 2, says so, writes nothing" yes (string match -q -- "*'$w' is a reserved word in fish*st=2" "$out"; and not test -e $tmp/out/$w.fish; and echo yes; or echo no)
end
printf 'function set\n    echo hi\nend\n' >$tmp/src-set.fish
set -l out (_ft $tmp "__fish_template_write set $tmp/src-set.fish $tmp/out; echo st=\$status")
check "a function fish cannot load fails the write and leaves no file" yes (string match -q -- '*st=1' "$out"; and not string match -q -- '*is ready*' "$out"; and not test -e $tmp/out/set.fish; and echo yes; or echo no)

section "cli: --from, --preset, list, info, ls"
printf '%s\n' "set -l __ft_use command" "set -l command_cmd probe (touch $tmp/canary)" >$tmp/recipe.fish
set -l out (_ft $tmp "fish-template new fr --from $tmp/recipe.fish --yes $o >/dev/null; echo st=\$status")
check "--from builds from a recipe file and never runs it" "st=0 no" "$out[-1] $(test -e $tmp/canary; and echo yes; or echo no)"
for p in (path change-extension '' (path basename $repo_root/templates/presets/*.fish))
    set -l out (_ft $tmp "fish-template new tp-$p --preset $p --yes --dry-run $o >$tmp/p.fish; echo st=\$status; fish -n $tmp/p.fish; and echo ok")
    check "preset $p generates valid code" "st=0 ok" "$out"
end
set -l out (_ft $tmp "fish-template list")
check "list shows every kind" yes (string match -q -- '*command*retry*allow-telemetry*' "$out"; and echo yes; or echo no)
set -l out (_ft $tmp "fish-template info retry")
check "info shows settings and defaults" yes (string match -q -- '*retry_attempts*default: 3*' "$out"; and echo yes; or echo no)
set -l out (_ft $tmp "fish-template info nope; echo st=\$status")
check "info on an unknown template is 2" st=2 "$out[-1]"
printf 'function hand\n    echo hi\nend\n' >$tmp/out/hand.fish
set -l out (_ft $tmp "fish-template ls $o")
set -l names (string match -v -- probe $out | string match -v -- printf | path sort)
check "ls lists only generated functions" "fr pw" "$names"
rm -rf $tmp

section "cli: wizard and edit"
set -l tmp (mktemp -d)
mkdir -p $tmp/bin
printf '#!/bin/sh\necho "args=$*"; exit 7\n' >$tmp/bin/probe
chmod +x $tmp/bin/probe
set -l o "--output $tmp/out"
# name, target, modifiers, command_cmd, retry_attempts, retry_delay, preview, write
set -l out (printf '%s\n' wz command retry probe 4 0 n y | _ft $tmp "fish-template new $o; echo st=\$status")
check "new from scratch through __fish_template_wizard" st=0 "$out[-1]"
check "answers land in the recipe" "set -l retry_attempts 4" (string trim -- (string match -r '.*set -l retry_attempts .*' <$tmp/out/wz.fish))

set -l out (printf '%s\n' wz2 bogus command '' probe | _ft $tmp "fish-template new $o; echo st=\$status")
check "an invalid target is asked again; EOF at the write question writes nothing" yes (string match -q -- '*Choose one of*Nothing written.*st=1' "$out"; and not test -e $tmp/out/wz2.fish; and echo yes; or echo no)

set -l out (printf '%s\n' wz3 command '' | _ft $tmp "fish-template new $o; echo st=\$status")
check "EOF mid-wizard cancels and writes nothing" yes (string match -q -- '*Cancelled*st=1' "$out"; and not test -e $tmp/out/wz3.fish; and echo yes; or echo no)

set -l out (printf '%s\n' wz4 sequence '' 'echo one' 'echo two' '' '' n y | _ft $tmp "fish-template new $o; echo st=\$status")
check "line settings take one entry per line" "set -l sequence_steps 'echo one' 'echo two'" (string trim -- (string match -r '.*set -l sequence_steps .*' <$tmp/out/wz4.fish))

# edit: keep the target and modifiers, keep command_cmd, change retry_attempts to 6, keep the delay
set -l out (printf '%s\n' '' '' '' 6 '' n y | _ft $tmp "fish-template edit wz $o; echo st=\$status")
check "edit offers current values as defaults" "set -l retry_attempts 6" (string trim -- (string match -r '.*set -l retry_attempts .*' <$tmp/out/wz.fish))
check "edit keeps untouched values" "set -l command_cmd probe" (string trim -- (string match -r '.*set -l command_cmd .*' <$tmp/out/wz.fish))

printf 'function hand\n    echo hi\nend\n' >$tmp/out/hand.fish
set -l before (cat $tmp/out/hand.fish | string collect)
set -l out (_ft $tmp "fish-template edit hand $o </dev/null; echo st=\$status")
check "edit refuses a hand-written function" yes (string match -q -- '*not a function made by fish-template*st=1' "$out"; and test "$before" = "$(cat $tmp/out/hand.fish | string collect)"; and echo yes; or echo no)

set -l out (_ft $tmp "__fish_template_prompt command command_cmd list 1 'Command' </dev/null; echo st=\$status")
check "prompt returns 1 on EOF" st=1 "$out[-1]"

# reserved word, then a valid name: asked again, the valid name is used
set -l out (printf '%s\n' set wz5 command '' probe 1 0 n y | _ft $tmp "fish-template new $o; echo st=\$status")
check "the wizard re-asks a reserved-word name" yes (string match -q -- "*'set' is a reserved word in fish*st=0" "$out"; and test -e $tmp/out/wz5.fish; and not test -e $tmp/out/set.fish; and echo yes; or echo no)
set -l out (_ft $tmp "__fish_template_name_ok set; and echo ok; __fish_template_name_ok good_name; and echo ok; __fish_template_name_ok -bad; and echo ok")
check "__fish_template_name_ok accepts only usable names" ok "$out"
rm -rf $tmp

section "cli: show, --from and regen round trips"
set -l tmp (mktemp -d)
set -l o "--output $tmp/out"
# Awkward values: a quote, a $, parentheses and a leading dash.
set -l sets (string escape -- 'env_set=A=it'\''s a $test' 'env_set=B=(x)' confirm_only_if=--force)
_ft $tmp "fish-template new rt --target command --with env,confirm --set command_cmd=probe --set $sets[1] --set $sets[2] --set $sets[3] --yes $o" >/dev/null
_ft $tmp "fish-template show rt $o" >$tmp/rt.recipe
_ft $tmp "fish-template new rt --from $tmp/rt.recipe --yes --output $tmp/out2" >/dev/null
check "show then --from rebuilds a byte-identical file" same (cmp -s $tmp/out/rt.fish $tmp/out2/rt.fish; and echo same; or echo differs)
cp $tmp/out/rt.fish $tmp/before.fish
set -l out (_ft $tmp "fish-template regen rt $o; echo st=\$status")
check "regen is idempotent" "same st=0" "$(cmp -s $tmp/before.fish $tmp/out/rt.fish; and echo same; or echo differs) $out[-1]"
string replace 'set -l command_cmd probe' 'set -l command_cmd probe
    set -l stale_key 1' <$tmp/before.fish >$tmp/out/rt.fish
set -l out (_ft $tmp "fish-template regen --all $o; echo st=\$status")
check "regen --all drops unknown settings with a warning" yes (string match -q -- '*ignoring unknown setting stale_key*st=0' "$out"; and not string match -q '*stale_key*' <$tmp/out/rt.fish; and echo yes; or echo no)
printf 'function hand\n    echo hi\nend\n' >$tmp/out/hand.fish
set -l out (_ft $tmp "fish-template regen hand $o; echo st=\$status")
check "regen refuses a hand-written function" st=1 "$out[-1]"
set -l out (_ft $tmp "fish-template regen $o; echo st=\$status")
check "regen with no names is a usage error" st=2 "$out[-1]"
rm -rf $tmp

report
