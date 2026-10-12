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

section "templates: args"
set -l tmp (mktemp -d)
_tpl_stub $tmp probe 'echo "args=$*"; exit 7'
_tpl_gen $tmp ag "__ft_use command args" "command_cmd probe" "args_prepend -x" "args_append --end"
check "prepend before, append after your arguments" "args=-x a --end" "$(_tpl_out $tmp 'ag a')"
rm -rf $tmp

section "templates: env"
set -l tmp (mktemp -d)
_tpl_stub $tmp envp 'echo "FOO=[$FOO] DNT=[$DNT] KEEP=[$KEEP]"'
_tpl_gen $tmp ev "__ft_use command env" "command_cmd envp" "env_set 'FOO=bar baz'" "env_unset DNT"
set -l out (_tpl_run $tmp "set -gx DNT 1; set -gx KEEP 1; ev; echo parent=\$DNT foo=\"\$FOO\"")
check "sets and removes variables for the command only" "FOO=[bar baz] DNT=[] KEEP=[1]" "$out[1]"
check "the calling shell is untouched" "parent=1 foo=" "$out[2]"
_tpl_gen $tmp envp "__ft_use command env" "command_cmd envp" "env_unset DNT"
check "same-name wrapper with env -u does not recurse" "FOO=[] DNT=[] KEEP=[]" "$(_tpl_out $tmp 'set -gx DNT 1; envp')"
_tpl_stub $tmp probe 'echo "args=$*"; exit 7'
_tpl_gen $tmp ee "__ft_use command env" "command_cmd probe" env_set env_unset
check "empty lists change nothing" "args=q st=7" "$(_tpl_out $tmp 'ee q; echo st=$status')"
rm -rf $tmp

section "templates: confirm"
set -l tmp (mktemp -d)
_tpl_stub $tmp probe 'echo "args=$*"; exit 7'
_tpl_gen $tmp cf "__ft_use command confirm" "command_cmd probe" "confirm_prompt 'Go?'" confirm_only_if
set -l out (_tpl_run $tmp "echo n | cf x; echo st=\$status")
check "declined: Aborted and 1, command not run" yes (string match -q -- '*Aborted.*st=1' "$out"; and not string match -q -- '*args=*' "$out"; and echo yes; or echo no)
set -l out (_tpl_run $tmp "echo y | cf x; echo st=\$status")
check "accepted: runs" yes (string match -q -- '*args=x*st=7' "$out"; and echo yes; or echo no)
_tpl_gen $tmp co "__ft_use command confirm" "command_cmd probe" "confirm_prompt 'Go?'" "confirm_only_if --force"
check "only_if miss: no question" "args=x st=7" "$(_tpl_out $tmp 'co x </dev/null; echo st=$status')"
set -l out (_tpl_run $tmp "echo n | co --force; echo st=\$status")
check "only_if hit: asks" st=1 "$out[-1]"
rm -rf $tmp

section "templates: in-dir"
set -l tmp (mktemp -d)
mkdir $tmp/work
_tpl_stub $tmp wd 'echo "$PWD"; exit 7'
_tpl_gen $tmp iw "__ft_use command in-dir" "command_cmd wd" "indir_dir $tmp/work"
set -l out (_tpl_run $tmp "builtin cd /; iw; echo st=\$status; pwd")
check "runs inside the directory and returns, even on failure" "$tmp/work st=7 /" "$out"
_tpl_gen $tmp im "__ft_use command in-dir" "command_cmd wd" "indir_dir $tmp/nope"
set -l out (_tpl_run $tmp "builtin cd /; im; echo st=\$status; pwd")
check "missing directory: 1, PWD unchanged" "st=1 /" "$out[-2..-1]"
_tpl_gen $tmp ic "__ft_use command in-dir confirm" "command_cmd wd" "indir_dir $tmp/work" "confirm_prompt 'Go?'" confirm_only_if
set -l out (_tpl_run $tmp "builtin cd /; echo n | ic; pwd")
check "declined confirm leaves PWD alone" / "$out[-1]"
rm -rf $tmp

section "templates: retry"
set -l tmp (mktemp -d)
_tpl_stub $tmp flaky 'n=$(cat '$tmp'/count 2>/dev/null || echo 0); n=$((n+1)); echo $n >'$tmp'/count; [ $n -ge 3 ]'
_tpl_gen $tmp rt "__ft_use command retry" "command_cmd flaky" "retry_attempts 3" "retry_delay 0"
check "succeeds on the third try" "st=0 3" "$(_tpl_out $tmp 'rt; echo st=$status')"" "(cat $tmp/count)
rm $tmp/count
_tpl_gen $tmp r2 "__ft_use command retry" "command_cmd flaky" "retry_attempts 2" "retry_delay 0"
check "gives up after the last attempt" "st=1 2" "$(_tpl_out $tmp 'r2; echo st=$status')"" "(cat $tmp/count)
rm -rf $tmp

section "templates: timeout"
set -l tmp (mktemp -d)
_tpl_stub $tmp slow 'sleep 3'
_tpl_gen $tmp to "__ft_use command timeout" "command_cmd slow" "timeout_seconds 1"
check "stops a long run with 124" st=124 "$(_tpl_out $tmp 'to; echo st=$status')"
_tpl_gen $tmp slow "__ft_use command env timeout" "command_cmd slow" "env_unset DNT" "timeout_seconds 1"
check "same-name wrapper with env and timeout does not recurse" st=124 "$(_tpl_out $tmp 'slow; echo st=$status')"
rm -rf $tmp

section "templates: log"
set -l tmp (mktemp -d)
_tpl_stub $tmp say 'echo hi; exit 7'
_tpl_gen $tmp lg "__ft_use command log" "command_cmd say" "log_file $tmp/logs/out.log" "log_mode append"
set -l out (_tpl_run $tmp "lg; echo st=\$status; lg >/dev/null")
check "output is shown and the status survives the pipe" "hi st=7" "$out"
check "append mode keeps every run (directory created)" 2 (count (cat $tmp/logs/out.log))
_tpl_gen $tmp lo "__ft_use command log" "command_cmd say" "log_file $tmp/o.log" "log_mode overwrite"
_tpl_run $tmp "lo; lo" >/dev/null
check "overwrite mode keeps only the last run" 1 (count (cat $tmp/o.log))
_tpl_gen $tmp lr "__ft_use command log retry" "command_cmd say" "log_file $tmp/r.log" "log_mode overwrite" "retry_attempts 2" "retry_delay 0"
_tpl_run $tmp lr >/dev/null
check "overwrite still logs every attempt of one run" 2 (count (cat $tmp/r.log))
rm -rf $tmp

section "templates: notify"
set -l tmp (mktemp -d)
_tpl_stub $tmp say 'echo hi; exit 7'
_tpl_stub $tmp ok 'exit 0'
_tpl_stub $tmp notify-send 'printf "%s|" "$@" >'$tmp'/notified'
_tpl_gen $tmp nf "__ft_use command notify" "command_cmd say" "notify_on fail" notify_title
_tpl_run $tmp nf >/dev/null
check "fail: notifies with the status" "--|nf|Failed with exit status 7|" (cat $tmp/notified)
rm -f $tmp/notified
_tpl_gen $tmp ns "__ft_use command notify" "command_cmd ok" "notify_on fail" "notify_title Backup"
_tpl_run $tmp ns >/dev/null
check "fail only: a success stays quiet" no (test -e $tmp/notified; and echo yes; or echo no)
_tpl_gen $tmp na "__ft_use command notify" "command_cmd ok" "notify_on always" "notify_title Backup"
_tpl_run $tmp na >/dev/null
check "always: notifies success with the title" "--|Backup|Finished successfully|" (cat $tmp/notified)
rm -rf $tmp

section "templates: full stack"
set -l tmp (mktemp -d)
mkdir $tmp/work
_tpl_stub $tmp probe 'echo "args=$* dir=$PWD FOO=$FOO"; exit 0'
_tpl_stub $tmp notify-send 'exit 0'
_tpl_gen $tmp all "__ft_use command notify log retry timeout env args confirm in-dir" "command_cmd probe" \
    "indir_dir $tmp/work" "args_prepend -v" "env_set FOO=1" "confirm_prompt 'Go?'" "timeout_seconds 5" \
    "retry_attempts 2" "log_file $tmp/all.log" "notify_on always"
set -l out (_tpl_run $tmp "builtin cd /; echo y | all a; echo st=\$status; pwd")
check "every modifier at once" yes (string match -q -- "*args=-v a dir=$tmp/work FOO=1*st=0 /" "$out"; and echo yes; or echo no)
check "recipe is written in canonical order" "set -l __ft_use command in-dir args env confirm timeout retry log notify" (string trim -- (string match -r '.*set -l __ft_use .*' <$tmp/functions/all.fish))
rm -rf $tmp

section "templates: command and fallback, same-name edge cases"
set -l tmp (mktemp -d)
_tpl_gen $tmp nobin "__ft_use command" "command_cmd nobin"
set -l out (_tpl_run $tmp "nobin; echo st=\$status")
check "same-name command with no binary: 127" st=127 "$out[-1]"
check "same-name command with no binary: says command not found" yes (string match -q -- '*command not found*' "$out"; and echo yes; or echo no)
_tpl_stub $tmp probe 'echo "args=$*"; exit 7'
_tpl_gen $tmp fbs "__ft_use fallback" "fallback_candidates fbs probe"
check "same-name fallback candidate without a binary falls through to the next" "args=q st=7" "$(_tpl_out $tmp 'fbs q; echo st=$status')"
_tpl_stub $tmp fbs 'echo "fbs-binary $*"; exit 3'
check "same-name fallback candidate with a binary runs the binary" "fbs-binary q st=3" "$(_tpl_out $tmp 'fbs q; echo st=$status')"
rm -rf $tmp

report
