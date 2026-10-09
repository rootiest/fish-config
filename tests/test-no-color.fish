#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# NO_COLOR coverage (https://no-color.org): when NO_COLOR is set to a
# NON-EMPTY value, the shared palette and every direct colour producer in
# functions/ must emit no escape sequences; an empty NO_COLOR does not count.
#
# Runs isolated (no `# MODE:` marker). Two halves:
#   1. __fish_palette and __fish_color, called in this process.
#   2. A representative set of user-facing functions run as children
#      (`fish --no-config`, sandboxed HOME, TERM=xterm-256color) with their
#      stdout+stderr captured, asserting no ESC byte under NO_COLOR and that
#      the same call DOES emit one without it.
#
# The positive half needs no pty: set_color output depends on $TERM, not on
# whether stdout is a terminal (see the note in functions/__fish_palette.fish),
# so a pipe with TERM=xterm-256color is enough to force colour.

source (realpath (dirname (status filename)))/lib.fish

set -g sb (mktemp -d)
mkdir -p $sb/home $sb/cfg $sb/data $sb/work

set -gx TERM xterm-256color
set -g fish_function_path $repo_root/functions $fish_function_path

# ---- Half 1: the palette, in-process ----------------------------------------

set -g palette_roles c_reset c_cmd c_flag c_arg c_dim c_head c_warn c_err c_ok \
    c_accent c_sel c_hi

# Prints "<non-empty> <empty-string> <unset>" role counts after __fish_palette.
function palette_state
    __fish_palette
    set -l full 0
    set -l empty 0
    set -l missing 0
    for r in $palette_roles
        if not set -q $r
            set missing (math $missing + 1)
        else if test -n "$$r"
            set full (math $full + 1)
        else
            set empty (math $empty + 1)
        end
    end
    echo "$full $empty $missing"
end

# Prints how many words `$c_err"text"` expands to: it must stay 1 with the
# role empty, since an empty LIST would annihilate the word.
function palette_word_count
    __fish_palette
    count $c_err"text"
end

section "NO_COLOR: palette roles"

set -gx NO_COLOR 1
check "NO_COLOR=1: all 12 roles are empty strings" "0 12 0" (palette_state)
check "NO_COLOR=1: \$c_err\"text\" is still one word" 1 (palette_word_count)

set -gx NO_COLOR anything
check "NO_COLOR=anything: all 12 roles are empty strings" "0 12 0" (palette_state)

set -gx NO_COLOR 0
check "NO_COLOR=0 (non-empty): still disables colour" "0 12 0" (palette_state)

set -gx NO_COLOR ''
check "NO_COLOR='' (empty): palette stays populated" "12 0 0" (palette_state)

set -e NO_COLOR
check "NO_COLOR unset: palette populated" "12 0 0" (palette_state)

section "NO_COLOR: __fish_color"

set -gx NO_COLOR 1
check "NO_COLOR=1: yields exactly one element" 1 (count (__fish_color red))
check "NO_COLOR=1: that element is empty" "" (__fish_color --bold red)
check "NO_COLOR=1: concatenation keeps its text" msg (echo (__fish_color red)"msg"(__fish_color normal))

set -gx NO_COLOR ''
check "NO_COLOR='' : emits an escape" true (__fish_color red | string match -qr \e; and echo true; or echo false)

set -e NO_COLOR
check "NO_COLOR unset: emits an escape" true (__fish_color red | string match -qr \e; and echo true; or echo false)
check "NO_COLOR unset: matches set_color exactly" (set_color --bold red | string escape) (__fish_color --bold red | string escape)

# ---- Half 2: user-facing functions as children ------------------------------

# probe <mode> <command...>: run the command in a sandboxed --no-config fish
# in an empty non-git directory; mode is nocolor | unset | empty. Prints the
# combined stdout+stderr.
function probe --argument-names mode
    # `env -u` must come before the VAR=value words (GNU env stops option
    # parsing at the first non-option).
    set -l envs
    switch $mode
        case nocolor
            set envs NO_COLOR=1
        case empty
            set envs NO_COLOR=
        case '*'
            set envs -u NO_COLOR
    end
    set -a envs HOME=$sb/home XDG_CONFIG_HOME=$sb/cfg XDG_DATA_HOME=$sb/data \
        TERM=xterm-256color GIT_CEILING_DIRECTORIES=$sb
    env $envs fish --no-config -c "set -g fish_function_path $repo_root/functions \$fish_function_path; cd $sb/work; $argv[2..]" 2>&1 | string collect
end

function has_esc
    string match -qr \e -- $argv[1]
    and echo true
    or echo false
end

# Each entry is "<label>|<command>". Palette-driven callers and callers that
# used a bare set_color before this change are both represented.
set -l cases \
    "git-clean --help (palette)|git-clean --help" \
    "config-help --help (palette)|config-help --help" \
    "fish-deps --help (palette)|fish-deps --help" \
    "gitignore-scrub --help (palette)|gitignore-scrub --help" \
    "config-help bad option (palette, stderr)|config-help --bogus-option" \
    "fish-deps status (direct, statements)|fish-deps status" \
    "poke no args (direct, cmdsub, stderr)|poke" \
    "open-url no URL (direct, statements, stderr)|open-url" \
    "repo-open outside a repo (direct, statements, stderr)|repo-open" \
    "gitignore-scrub outside a repo (direct, statement + cmdsub)|gitignore-scrub" \
    "gi outside a repo (direct, statement + cmdsub)|gi python" \
    "scrub bad option (direct, cmdsub)|scrub --bogus-option" \
    "dng2avif missing file (direct, cmdsub)|dng2avif $sb/work/missing.dng"

section "NO_COLOR: user-facing functions emit no escape sequences"
for entry in $cases
    set -l parts (string split -m1 '|' -- $entry)
    set -l out (probe nocolor $parts[2])
    check "NO_COLOR=1: $parts[1]: no ESC byte" false (has_esc "$out")
    check "NO_COLOR=1: $parts[1]: still prints something" true (test -n "$out"; and echo true; or echo false)
end

section "NO_COLOR: colour still emitted when it is unset or empty"
for entry in $cases
    set -l parts (string split -m1 '|' -- $entry)
    check "NO_COLOR unset: $parts[1]: emits ESC" true (has_esc (probe unset $parts[2]))
end
set -l parts (string split -m1 '|' -- $cases[1])
check "NO_COLOR='': $parts[1]: emits ESC" true (has_esc (probe empty $parts[2]))
set -l parts (string split -m1 '|' -- $cases[7])
check "NO_COLOR='': $parts[1]: emits ESC" true (has_esc (probe empty $parts[2]))

# The message text must survive with colour off (an empty list in a
# concatenation would silently drop the whole line).
section "NO_COLOR: messages survive with colour off"
check "poke: error text intact" "poke: no file specified" (probe nocolor poke)
check "open-url: error text intact" "error: open-url requires a URL argument" (probe nocolor open-url)

command rm -rf $sb
report
