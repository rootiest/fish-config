#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for functions/fc.fish (issue #229): the scratch file is private and
# always removed, a multi-word $EDITOR is split into words, and multi-line
# history entries keep their newlines.
#
# Runs isolated (no `# MODE:` marker). The editor is a stub script, history is
# a throwaway one under a temp XDG_DATA_HOME, and `commandline` is replaced by
# a recorder (fc only works at an interactive prompt otherwise).

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -l sandbox (path resolve (mktemp -d))
mkdir -p $sandbox/tmp $sandbox/data $sandbox/rec
set -gx TMPDIR $sandbox/tmp
set -gx XDG_DATA_HOME $sandbox/data
set -g fish_history fc_test
set -gx REC $sandbox/rec

# Stub editor: records what fc handed it, then optionally edits the buffer.
printf '%s\n' '#!/bin/sh' \
    'printf "%s\n" "$1" >"$REC/path"' \
    'stat -c %a "$1" >"$REC/mode"' \
    'cp "$1" "$REC/content"' \
    'echo "${FC_X:-unset}" >"$REC/env"' \
    '[ -n "$FC_EXIT" ] && exit "$FC_EXIT"' \
    '[ -n "$FC_EMPTY" ] && : >"$1"' \
    '[ -n "$FC_APPEND" ] && printf "%s\n" "$FC_APPEND" >>"$1"' \
    'exit 0' >$sandbox/ed.sh
chmod +x $sandbox/ed.sh

# `commandline` recorder.
set -g __cl_calls
function commandline
    set -a __cl_calls (string join '|' -- $argv | string collect)
end

history append "echo one"
history append "for i in 1 2
echo \$i
end"
history append fc

section "fc: multi-word EDITOR, multi-line entry"
set -gx EDITOR "env FC_X=yes $sandbox/ed.sh"
fc
check "fc returns 0" 0 $status
check "editor ran with its argument" yes (cat $sandbox/rec/env)
check "editor received the multi-line entry" "for i in 1 2
echo \$i
end" (string collect <$sandbox/rec/content)
check "buffer replaced, then executed" "-r|--|for i in 1 2
echo \$i
end -f|execute" (string join ' ' -- $__cl_calls | string collect)
check "scratch file is mode 600" 600 (cat $sandbox/rec/mode)
check "scratch file ends in .fish" .fish (string match -r '\.fish$' (cat $sandbox/rec/path))
check "scratch file removed" "" (command ls -A $sandbox/tmp | string collect)

section "fc: prefix search keeps newlines"
set __cl_calls
fc "for i"
check "searched entry executed" "-r|--|for i in 1 2
echo \$i
end -f|execute" (string join ' ' -- $__cl_calls | string collect)

section "fc: edits are applied"
set __cl_calls
set -gx FC_APPEND "echo edited"
fc
set -e FC_APPEND
check "edit appended a line" "-r|--|for i in 1 2
echo \$i
end
echo edited -f|execute" (string join ' ' -- $__cl_calls | string collect)

section "fc: editor failure still cleans up"
set -gx FC_EXIT 3
fc >/dev/null 2>&1
set -e FC_EXIT
check "scratch file removed after failing editor" "" (command ls -A $sandbox/tmp | string collect)

section "fc: empty buffer aborts"
set __cl_calls
set -gx FC_EMPTY 1
fc 2>/dev/null
set -l st $status
set -e FC_EMPTY
check "returns 1" 1 $st
check "nothing queued" "" (string join ' ' -- $__cl_calls | string collect)
check "scratch file removed" "" (command ls -A $sandbox/tmp | string collect)

section "fc: unset EDITOR falls back to vi"
set -e EDITOR
check "vi is the fallback" vi (begin
    set -l editor
    echo $EDITOR | read -at editor
    set -q editor[1]; or set editor vi
    echo $editor
end)

functions -e commandline
set -e TMPDIR XDG_DATA_HOME REC
rm -rf $sandbox
report
