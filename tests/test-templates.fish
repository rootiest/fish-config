#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for templates/: the template contract (metadata, prefixed and
# prompted settings, fragments) for every target and modifier, and each
# one's runtime behavior. Functions are generated straight from
# __fish_template_store, __fish_template_validate and
# __fish_template_assemble, so this suite tests the templates rather than
# the fish-template CLI (tests/test-fish-template.fish covers that), and
# each generated function runs against stub binaries in a --no-config fish.

source (realpath (dirname (status filename)))/lib.fish
set -g fish_function_path $repo_root/functions $fish_function_path

# Generate function NAME into DIR/functions/NAME.fish. Each RECIPE entry is
# fish syntax for `KEY VALUE...`, e.g. "command_cmd probe" or
# "sequence_steps 'echo one' false". Prints any errors.
function _tpl_gen --argument-names dir name
    mkdir -p $dir/functions
    set -l lines
    for r in $argv[3..]
        set -a lines "__fish_template_store set --mark $r"
    end
    env TERM=dumb fish --no-config -c "set -g fish_function_path $repo_root/functions \$fish_function_path
        $(string join \n -- $lines)
        __fish_template_validate; or exit 2
        __fish_template_assemble $name >$dir/functions/$name.fish"
end

# Run SCRIPT in a fresh fish that autoloads DIR/functions, with DIR/bin
# first on PATH. Prints stdout and stderr.
function _tpl_run --argument-names dir script
    env TERM=dumb PATH="$dir/bin:$PATH" fish --no-config -c "set -g fish_function_path $dir/functions $repo_root/functions \$fish_function_path
        $script" 2>&1
end

# _tpl_run with the output lines joined by single spaces, for one-string checks.
function _tpl_out --argument-names dir script
    _tpl_run $dir $script | string join ' '
end

# Install a /bin/sh stub named NAME in DIR/bin that runs BODY.
function _tpl_stub --argument-names dir name body
    mkdir -p $dir/bin
    printf '#!/bin/sh\n%s\n' $body >$dir/bin/$name
    chmod +x $dir/bin/$name
end

section "templates: contract"
for f in $repo_root/templates/targets/*.fish $repo_root/templates/modifiers/*.fish
    set -l t (path change-extension '' (path basename $f))
    set -l kind (__fish_template_meta $f KIND)
    set -l bad
    test "$(__fish_template_meta $f TEMPLATE)" = $t; or set -a bad TEMPLATE
    contains -- "$kind" target modifier; or set -a bad KIND
    for k in SUMMARY PHRASE
        __fish_template_meta $f $k >/dev/null; or set -a bad $k
    end
    if test "$kind" = target
        for k in SYNOPSIS STATUS EXAMPLE
            __fish_template_meta $f $k >/dev/null; or set -a bad $k
        end
        __fish_template_fragment $f run >/dev/null; or set -a bad run-fragment
    else
        string match -qr '^[0-9]+$' -- "$(__fish_template_meta $f ORDER)"; or set -a bad ORDER
        __fish_template_meta $f APPLIES >/dev/null; or set -a bad APPLIES
        set -l phases
        for p in guard prepare finally
            __fish_template_fragment $f $p >/dev/null; and set -a phases $p
        end
        set -q phases[1]; or set -a bad fragment
    end
    set -l prefix (string replace -a -- - '' $t)_
    for row in (__fish_template_settings $f)
        set -l c (string split \t -- $row)
        string match -q -- "$prefix*" $c[1]; or set -a bad prefix:$c[1]
        test -n "$c[4]"; or set -a bad prompt:$c[1]
        contains -- $c[2] text int bool path list lines
        or string match -q 'choice:*' -- $c[2]
        or set -a bad type:$c[1]
    end
    check "$t follows the template contract" "" "$bad"
end

section "templates: command"
set -l tmp (mktemp -d)
_tpl_stub $tmp probe 'echo "args=$*"; exit 7'
_tpl_gen $tmp pw "__ft_use command" "command_cmd probe"
set -l out (_tpl_run $tmp "pw a 'b c'; echo st=\$status")
check "forwards arguments" "args=a b c" "$out[1]"
check "passes the exit status through" st=7 "$out[2]"
set -l out (_tpl_run $tmp "pw --help")
check "own --help prints the generated header" yes (string match -q -- '*pw [ARGS...]*' "$out"; and echo yes; or echo no)
_tpl_gen $tmp probe "__ft_use command" "command_cmd probe"
set -l out (_tpl_run $tmp "probe x; echo st=\$status; probe --help")
check "a same-name wrapper runs the binary, not itself" "args=x st=7" "$out[1..2]"
check "a same-name wrapper forwards --help to the binary" args=--help "$out[3]"
_tpl_gen $tmp nw "__ft_use command" "command_cmd no-such-binary-xyz"
set -l out (_tpl_run $tmp "nw; echo st=\$status")
check "a missing command exits 127" st=127 "$out[-1]"
rm -rf $tmp

section "templates: fallback"
set -l tmp (mktemp -d)
_tpl_stub $tmp probe 'echo "args=$*"; exit 7'
_tpl_gen $tmp fb "__ft_use fallback" "fallback_candidates no-such-a probe"
set -l out (_tpl_run $tmp "fb z; echo st=\$status")
check "runs the first installed candidate" "args=z st=7" "$out"
_tpl_gen $tmp fn "__ft_use fallback" "fallback_candidates no-such-a no-such-b"
set -l out (_tpl_run $tmp "fn; echo st=\$status")
check "none installed: message and 127" "fn: none of these is installed: no-such-a no-such-b st=127" "$out"
rm -rf $tmp

section "templates: sequence"
set -l tmp (mktemp -d)
_tpl_gen $tmp sq "__ft_use sequence" "sequence_steps 'echo one' false 'echo three'" "sequence_on_fail stop"
check "stop: halts at the failing step and returns its status" "one st=1" "$(_tpl_out $tmp 'sq; echo st=$status')"
_tpl_gen $tmp sc "__ft_use sequence" "sequence_steps 'echo one' false 'echo three'" "sequence_on_fail continue"
check "continue: runs every step, returns the last failure" "one three st=1" "$(_tpl_out $tmp 'sc; echo st=$status')"
_tpl_gen $tmp so "__ft_use sequence" "sequence_steps 'echo a' 'echo b'" "sequence_on_fail stop"
check "all steps succeed: 0" "a b st=0" "$(_tpl_out $tmp 'so; echo st=$status')"
rm -rf $tmp

section "templates: dispatcher"
set -l tmp (mktemp -d)
_tpl_gen $tmp dp "__ft_use dispatcher" "dispatcher_subcommands 'hi=echo hello' 'say=echo'" dispatcher_default
check "routes a subcommand" "hello st=0" "$(_tpl_out $tmp 'dp hi; echo st=$status')"
check "appends arguments literally, never evaluated" "a  b (x) st=0" "$(_tpl_out $tmp "dp say 'a  b' '(x)'; echo st=\$status")"
set -l out (_tpl_run $tmp "dp bogus; echo st=\$status")
check "unknown subcommand: usage hint and 2" yes (string match -q -- '*Run dp help for usage.*st=2' "$out"; and echo yes; or echo no)
set -l out (_tpl_run $tmp "dp; echo st=\$status")
check "bare call with no default shows help" yes (string match -q -- '*dp SUBCOMMAND*st=0' "$out"; and echo yes; or echo no)
_tpl_gen $tmp dd "__ft_use dispatcher" "dispatcher_subcommands 'hi=echo hello'" "dispatcher_default hi"
check "bare call runs the default" hello "$(_tpl_out $tmp dd)"
rm -rf $tmp

report
