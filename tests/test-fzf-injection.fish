#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Regression coverage for #218: the fzf preview helpers must never execute
# text taken from a filename or from the token under the cursor.
#   - _fzf_preview_file: a quote-bearing path reaches the user-configured
#     preview command (file and dir) as one inert argument, while a preview
#     command that carries its own arguments still works.
#   - _fzf_search_directory: expanding the current token must not run
#     $(...) / (...), yet a leading ~ and $VAR still expand.
#
# Runs isolated (no `# MODE:` marker): its own `fish --no-config` process,
# and every case works inside a mktemp -d sandbox.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -l start $PWD
set -l sandbox (path resolve (mktemp -d))
cd $sandbox

# ---- _fzf_preview_file -----------------------------------------------------
section "_fzf_preview_file: hostile filename stays inert"

# `command` bypasses this repo's cat/ls shadows so the assertions see plain output.
set -g fzf_preview_file_cmd "command cat"
set -g fzf_preview_dir_cmd "command ls"
set -l evil "a'; touch PWNED_file; echo '"
echo hi >$evil
_fzf_preview_file $evil >/dev/null 2>&1
check "file preview: no injected command ran" false (test -e PWNED_file; and echo true; or echo false)
check "file preview: content still reached the command" hi (_fzf_preview_file $evil 2>&1)

set -l evil_dir "d'; touch PWNED_dir; echo '"
mkdir $evil_dir
echo inside >$evil_dir/marker
_fzf_preview_file $evil_dir >/dev/null 2>&1
check "dir preview: no injected command ran" false (test -e PWNED_dir; and echo true; or echo false)
check "dir preview: listing still reached the command" marker (_fzf_preview_file $evil_dir 2>&1)

set -l evil_sub "x\$(touch PWNED_sub)y"
echo hi >$evil_sub
_fzf_preview_file $evil_sub >/dev/null 2>&1
check "command-substitution syntax in a name stays inert" false (test -e PWNED_sub; and echo true; or echo false)

section "_fzf_preview_file: configured command keeps its own arguments"

set -g fzf_preview_file_cmd "printf '%s|'"
set -l spaced "two words.txt"
echo hi >$spaced
check "multi-word command and spaced path" "two words.txt|" (_fzf_preview_file $spaced 2>&1)
set -e fzf_preview_file_cmd
set -e fzf_preview_dir_cmd

# ---- _fzf_search_directory -------------------------------------------------
section "_fzf_search_directory: token expansion is not an eval"

# Stub the interactive pieces so the function runs headless: the token under
# the cursor, the fzf wrapper (records its arguments, selects nothing), and
# the commit-back builtin calls.
set -g __stub_token ''
function commandline
    if contains -- --current-token $argv; and not contains -- --replace $argv
        printf '%s\n' $__stub_token
    end
end
function _fzf_wrapper
    set -g __stub_fzf_args $argv
    return 1
end

for token in '$(touch PWNED_tok1)' '(touch PWNED_tok2)' '"$(touch PWNED_tok3)"' 'x(touch PWNED_tok4)'
    set -g __stub_token $token
    _fzf_search_directory >/dev/null 2>&1
end
set -l ran
for f in PWNED_tok1 PWNED_tok2 PWNED_tok3 PWNED_tok4
    test -e $f; and set -a ran $f
end
check "command substitution in token did not run" "" "$ran"

mkdir -p home/sub
set -l saved_home $HOME
set -gx HOME $sandbox/home
set -gx FZF_TEST_DIR $sandbox/home/sub

set -g __stub_token '~/sub/'
_fzf_search_directory >/dev/null 2>&1
check "leading ~ expands to HOME" "Directory $sandbox/home/sub/> " (string replace -r '^--prompt=' '' -- $__stub_fzf_args | string match -r '^Directory .*> $')

set -g __stub_token '$FZF_TEST_DIR/'
_fzf_search_directory >/dev/null 2>&1
check "\$VAR expands" "Directory $sandbox/home/sub/> " (string replace -r '^--prompt=' '' -- $__stub_fzf_args | string match -r '^Directory .*> $')

mkdir -p "home/it's here"
set -g __stub_token "'$sandbox/home/it\\'s here/'"
_fzf_search_directory >/dev/null 2>&1
# fzf substitutes {} with the single-quoted entry; replay that in a fresh shell
# with a stub _fzf_preview_file to see which single path argument it receives.
set -l preview (string replace -r '^--preview=' '' -- $__stub_fzf_args | string match '_fzf_preview_file *' | string replace -- '{}' "'x'")
set -l got (fish --no-config -c "function _fzf_preview_file; count \$argv; printf '%s\n' \$argv; end; $preview" 2>&1)
check "quote-bearing directory token reaches the preview as one path" "1 $sandbox/home/it's here/x" "$got[1] $got[2]"

set -gx HOME $saved_home
set -e FZF_TEST_DIR
functions -e commandline _fzf_wrapper

cd $start
rm -rf $sandbox
report
