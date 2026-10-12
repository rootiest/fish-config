#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for the fzf.fish helpers and the clipboard bridge not already
# covered by test-fzf-injection.fish (#218) and test-fzf-helper-audit.fish
# (#255):
#   - the preview helpers (_fzf_preview_changed_file, _fzf_preview_image,
#     _fzf_preview_media) and their report banners (_fzf_report_diff_type,
#     _fzf_report_file_type): tool selection, exit status, and hostile file
#     names (spaces, quotes, `$`, `;`) reaching the renderer as one inert
#     argument;
#   - the search widgets (_fzf_search_git_log, _fzf_search_history,
#     _fzf_search_processes, __fzf_inline_picker): what they hand fzf and
#     what they write back to the command line, selection and cancel;
#   - _fzf_configure_bindings_help against fzf_configure_bindings' own spec;
#   - _fish_clipboard_copy/_fish_clipboard_paste provider fallback.
#
# Runs isolated (no `# MODE:` marker): its own `fish --no-config` process.
# Every case works inside a mktemp -d sandbox. fzf, commandline, and every
# renderer/clipboard binary are stubs (fish functions or scripts first on, or
# alone on, $PATH), so nothing here needs a terminal or touches the real
# clipboard; git runs for real, against throwaway repositories with the
# user's global and system git config switched off.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -gx TERM xterm-256color
set -e KITTY_WINDOW_ID TERM_PROGRAM GHOSTTY_RESOURCES_DIR
set -e FZF_PREVIEW_COLUMNS FZF_PREVIEW_LINES FZF_PREVIEW_LEFT FZF_PREVIEW_TOP
set -e fzf_preview_file_cmd fzf_preview_dir_cmd fzf_diff_highlighter
set -e fzf_git_log_opts fzf_history_opts fzf_processes_opts fzf_fd_opts

# Real git, but never the developer's config: no signing prompts, no hooks,
# a fixed default branch and identity.
set -gx GIT_CONFIG_GLOBAL /dev/null
set -gx GIT_CONFIG_NOSYSTEM 1
set -gx GIT_CONFIG_COUNT 2
set -gx GIT_CONFIG_KEY_0 init.defaultBranch
set -gx GIT_CONFIG_VALUE_0 main
set -gx GIT_CONFIG_KEY_1 commit.gpgsign
set -gx GIT_CONFIG_VALUE_1 false
set -gx GIT_AUTHOR_NAME Test
set -gx GIT_AUTHOR_EMAIL test@example.invalid
set -gx GIT_COMMITTER_NAME Test
set -gx GIT_COMMITTER_EMAIL test@example.invalid

set -l start $PWD
set -g sandbox (path resolve (mktemp -d))
set -gx GIT_CEILING_DIRECTORIES $sandbox
cd $sandbox
set -g logdir $sandbox/log
mkdir -p $logdir
set -g real_cat (command -s cat)

# Strip SGR escapes (set_color, git --color=always) for plain comparisons.
function __plain
    string replace -ra '\e\[[0-9;]*m' '' -- $argv
end

# __stub <dir> <name> <exit> [extra sh line]: a script that logs its argv one
# per line to $logdir/<name>.args, runs the optional extra line, then exits.
function __stub --argument-names dir name code
    mkdir -p $dir
    printf '%s\n' '#!/bin/sh' \
        "printf '%s\\n' \"\$@\" >'$logdir/$name.args'" \
        $argv[4..-1] "exit $code" >$dir/$name
    chmod +x $dir/$name
end

function __args --argument-names name
    test -f $logdir/$name.args; and command cat $logdir/$name.args
end

function __was_run --argument-names name
    test -f $logdir/$name.args; and echo true; or echo false
end

function __reset_log
    command rm -rf $logdir
    mkdir -p $logdir
end

# Run a command with $PATH replaced by exactly the given directory.
function __with_path --argument-names p
    set -lx PATH $p
    $argv[2..-1]
end

# ---- report banners --------------------------------------------------------
section "_fzf_report_diff_type / _fzf_report_file_type"

set -l banner (__plain (_fzf_report_diff_type Staged))
check "_fzf_report_diff_type: top border sized to the label" "╭────────╮" "$banner[1]"
check "_fzf_report_diff_type: label line" "│ Staged │" "$banner[2]"
check "_fzf_report_diff_type: bottom border" "╰────────╯" "$banner[3]"
check "_fzf_report_diff_type: nothing after the box" "" (string join '' -- $banner[4..-1])

set -l hostile "x'; touch PWNED_rf; \$(touch PWNED_rf) y"
check "_fzf_report_file_type: names the path and type verbatim" \
    "Cannot preview '$hostile': it is a named pipe." \
    (__plain (_fzf_report_file_type $hostile "named pipe"))
check "_fzf_report_file_type: hostile path stays inert" false (test -e PWNED_rf; and echo true; or echo false)

# ---- _fzf_preview_image ----------------------------------------------------
section "_fzf_preview_image: renderer selection"

set -l img "$sandbox/pic 'q' \$HOME; touch PWNED_img.png"
echo png >$img

set -l bin $sandbox/img_all
for t in kitten chafa viu timg file
    __stub $bin $t 0
end
__reset_log
__with_path $bin _fzf_preview_image $img
check "no kitty-capable terminal: kitten skipped" false (__was_run kitten)
check "chafa preferred when not kitty-capable" "--size=80x24 -- $img" "$(__args chafa | string join ' ')"

__reset_log
set -gx KITTY_WINDOW_ID 1
set -gx FZF_PREVIEW_COLUMNS 40
set -gx FZF_PREVIEW_LINES 10
set -gx FZF_PREVIEW_LEFT 2
set -gx FZF_PREVIEW_TOP 3
__with_path $bin _fzf_preview_image $img
set -l kargs (__args kitten)
check "KITTY_WINDOW_ID: kitten icat used" icat "$kargs[1]"
check "kitten placement from FZF_PREVIEW_*" true (contains -- --place=40x10@2x3 $kargs; and echo true; or echo false)
check "kitten gets the path last, after --" "-- $img" "$kargs[-2] $kargs[-1]"
check "kitten path: chafa not also run" false (__was_run chafa)
set -e KITTY_WINDOW_ID FZF_PREVIEW_COLUMNS FZF_PREVIEW_LINES FZF_PREVIEW_LEFT FZF_PREVIEW_TOP

for envcase in "TERM xterm-kitty" "TERM_PROGRAM WezTerm" "TERM_PROGRAM ghostty" "GHOSTTY_RESOURCES_DIR /x"
    set -l kv (string split ' ' $envcase)
    __reset_log
    set -gx $kv[1] $kv[2]
    __with_path $bin _fzf_preview_image $img
    check "$kv[1]=$kv[2] counts as kitty-capable" true (__was_run kitten)
    set -e $kv[1]
end
set -gx TERM xterm-256color

set -l bin $sandbox/img_nokitten
for t in chafa viu file
    __stub $bin $t 0
end
__reset_log
set -gx KITTY_WINDOW_ID 1
__with_path $bin _fzf_preview_image $img
check "kitty-capable but no kitten: falls back to chafa" true (__was_run chafa)
set -e KITTY_WINDOW_ID

set -l bin $sandbox/img_viu
__stub $bin viu 0
__stub $bin timg 0
__reset_log
__with_path $bin _fzf_preview_image $img
check "viu used when chafa is absent" "--width 80 -- $img" "$(__args viu | string join ' ')"
check "viu path: timg not run" false (__was_run timg)

set -l bin $sandbox/img_timg
__stub $bin timg 5
__reset_log
__with_path $bin _fzf_preview_image $img
check "timg exit status propagates" 5 $status
check "timg used as the last renderer" "-g 80x24 -- $img" "$(__args timg | string join ' ')"

set -l bin $sandbox/img_none
__stub $bin file 0 "echo 'PNG image data'"
__reset_log
set -l out (__plain (__with_path $bin _fzf_preview_image $img))
check "no renderer: explains what to install" true (string match -q 'No image preview tool available*' -- $out[1]; and echo true; or echo false)
check "no renderer: falls back to file --brief" "PNG image data" "$out[2]"
check "no renderer: file gets the path after --" "--brief -- $img" "$(__args file | string join ' ')"
check "hostile image name never ran its payload" false (test -e PWNED_img.png; and echo true; or echo false)

# ---- _fzf_preview_media ----------------------------------------------------
section "_fzf_preview_media: thumbnail cache, ffprobe, file"

set -gx XDG_CACHE_HOME $sandbox/cache
set -l bin $sandbox/media_bin
mkdir -p $bin
ln -s (command -s md5sum) $bin/md5sum
__stub $bin chafa 0
__stub $bin file 0 "echo 'ISO Media'"

set -l clip "$sandbox/my clip.mp4"
echo data >$clip
# freedesktop thumbnail spec: md5 of the file:// URI, spaces as %20.
set -l hash (printf '%s' "file://$sandbox/my%20clip.mp4" | md5sum | string split ' ')[1]
mkdir -p $XDG_CACHE_HOME/thumbnails/large
echo thumb >$XDG_CACHE_HOME/thumbnails/large/$hash.png
__reset_log
__with_path $bin _fzf_preview_media $clip >/dev/null
check "cached thumbnail found and rendered, status 0" 0 $status
check "renderer got the thumbnail path" "--size=80x24 -- $XDG_CACHE_HOME/thumbnails/large/$hash.png" "$(__args chafa | string join ' ')"
check "thumbnail path: file not consulted" false (__was_run file)

__reset_log
set -l missing "$sandbox/nope; touch PWNED_m.mp4"
set -l err (__with_path $bin _fzf_preview_media $missing 2>&1 >/dev/null)
check "missing file: status 0 (preview pane, not an error)" 0 $status
check "missing file: message on stderr" "$missing doesn't exist." "$err"

set -l evil "$sandbox/a'b;\$(touch PWNED_media) c.mkv"
echo data >$evil
__stub $bin ffprobe 0 "echo duration=1.5" "echo codec_name=h264"
__reset_log
set -l out (__with_path $bin _fzf_preview_media $evil)
check "no thumbnail: ffprobe metadata printed" "duration=1.5 codec_name=h264" "$out"
check "ffprobe gets the absolute path last, intact" "$evil" (__args ffprobe)[-1]
check "ffprobe path: file not consulted" false (__was_run file)
check "hostile media name never ran its payload" false (test -e PWNED_media; and echo true; or echo false)

__stub $bin ffprobe 0
__reset_log
set -l out (__with_path $bin _fzf_preview_media $evil)
check "empty ffprobe output: falls back to file" "ISO Media" "$out"
check "file gets the absolute path after --" "--brief -- $evil" "$(__args file | string join ' ')"
set -e XDG_CACHE_HOME

# ---- _fzf_preview_changed_file ---------------------------------------------
section "_fzf_preview_changed_file: real repository"

set -g fzf_preview_file_cmd "command cat"
set -l repo $sandbox/repo
mkdir -p $repo
cd $repo
git init -q
set -l evil_tracked "x;touch PWNED_cf;\$(touch PWNED_cf) y.txt"
echo base >$evil_tracked
echo base >both.txt
echo base >old.txt
echo base >conflict.txt
git add -A
git commit -qm init

# Feed the line exactly as `git status --short` produces it for one path.
function __status_line
    git -c color.status=false status --short -- $argv
end
function __preview
    __plain (_fzf_preview_changed_file (__status_line $argv) 2>&1)
end

echo untracked-body >"two words.txt"
set -l out (__preview "two words.txt")
check "untracked: banner" "│ Untracked │" "$out[2]"
check "untracked: file contents previewed" untracked-body "$out[-1]"

# git leaves a name with a single quote unquoted; it must not be unescaped
# into a different name (#316).
echo quote-body >"it's.txt"
set -l out (__preview "it's.txt")
check "untracked single-quote name: file found" quote-body "$out[-1]"
command rm "it's.txt"

echo staged-line >new.txt
git add new.txt
set -l out (__preview new.txt)
check "staged add: Staged banner" "│ Staged │" "$out[2]"
check "staged add: diff shows the new line" true (contains -- +staged-line $out; and echo true; or echo false)
check "staged add: no Unstaged banner" false (contains -- "│ Unstaged │" $out; and echo true; or echo false)

echo changed >$evil_tracked
set -l out (__preview $evil_tracked)
check "unstaged hostile name: Unstaged banner" "│ Unstaged │" "$out[2]"
check "unstaged hostile name: diff found the file" true (contains -- +changed $out; and echo true; or echo false)
check "unstaged hostile name: payload never ran" false (test -e PWNED_cf; and echo true; or echo false)

echo staged >both.txt
git add both.txt
echo unstaged >both.txt
set -l out (__preview both.txt)
check "MM: Staged banner" true (contains -- "│ Staged │" $out; and echo true; or echo false)
check "MM: Unstaged banner" true (contains -- "│ Unstaged │" $out; and echo true; or echo false)
check "MM: staged diff" true (contains -- +staged $out; and echo true; or echo false)
check "MM: unstaged diff" true (contains -- +unstaged $out; and echo true; or echo false)

git mv old.txt "new name.txt"
set -l line (git -c color.status=false status --short | string match 'R *')
set -l out (__plain (_fzf_preview_changed_file $line 2>&1))
check "rename: Staged banner" "│ Staged │" "$out[2]"
check "rename: diff resolves both sides" true (string match -q '*rename to new name.txt' -- $out; and echo true; or echo false)
git commit -qam wip

git checkout -qb side
echo side >conflict.txt
git commit -qam side
git checkout -q main
echo mainline >conflict.txt
git commit -qam mainline
git merge -q side >/dev/null 2>&1
set -l out (__preview conflict.txt)
check "conflict: Unmerged banner" "│ Unmerged │" "$out[2]"
check "conflict: diff shows conflict markers" true (string match -q '*<<<<<<<*' -- $out; and echo true; or echo false)
git merge --abort
set -e fzf_preview_file_cmd

# ---- _fzf_search_git_log ---------------------------------------------------
section "_fzf_search_git_log: selection to full hashes"

# commandline stub: answers the current-token query, records replacements
# and repaints.
set -g __tok ''
function commandline
    if contains -- --replace $argv
        set -l i (contains -i -- --replace $argv)
        set -l from (math $i + 1)
        set -g __replaced $argv[$from..-1]
        test "$__replaced[1]" = --; and set -e __replaced[1]
        set -g __did_replace 1
    else if contains -- repaint $argv
        set -g __repaints (math $__repaints + 1)
    else if contains -- --current-token $argv; or contains -- -t $argv
        printf '%s\n' $__tok
    else if test (count $argv) -eq 0
        printf '%s\n' $__tok
    end
end
function __reset_cl
    set -g __replaced
    set -g __did_replace 0
    set -g __repaints 0
    set -g __fzf_called 0
end

# fzf stub: records argv, picks lines $__pick of its input (stripping ANSI as
# `fzf --ansi` does), exits $__fzf_ret.
set -g __pick 1
set -g __fzf_ret 0
function _fzf_wrapper
    set -g __fzf_called 1
    set -g __fzf_args $argv
    # A command substitution does not see the function's stdin: spool it.
    command cat >$sandbox/fzf.stdin
    set -l in (__plain (command cat $sandbox/fzf.stdin))
    for i in $__pick
        printf '%s\n' $in[$i]
    end
    return $__fzf_ret
end
function __fzf_opt --argument-names prefix
    string match -- "$prefix*" $__fzf_args | string replace -- $prefix ''
end

set -l head (git rev-parse HEAD)
set -l parent (git rev-parse HEAD~1)
__reset_cl
set -g __tok '$(touch PWNED_gl)'
_fzf_search_git_log
check "one pick: token replaced with the full hash" $head "$__replaced"
check "repaint after selection" 1 $__repaints
check "current token passed verbatim as --query" '$(touch PWNED_gl)' (__fzf_opt --query=)
check "token payload never ran" false (test -e PWNED_gl; and echo true; or echo false)
check "default preview command" 'git show --color=always --stat --patch {1}' (__fzf_opt --preview=)

__reset_cl
set -g __tok ''
set -g __pick 1 2
set -g fzf_diff_highlighter 'delta --paging=never'
set -g fzf_git_log_opts --no-sort
_fzf_search_git_log
check "multi pick: hashes joined by spaces" "$head $parent" "$__replaced"
check "fzf_diff_highlighter piped into the preview" 'git show --color=always --stat --patch {1} | delta --paging=never' (__fzf_opt --preview=)
check "fzf_git_log_opts appended" --no-sort $__fzf_args[-1]
set -e fzf_diff_highlighter fzf_git_log_opts

__reset_cl
set -g __pick 1
set -g __fzf_ret 130
_fzf_search_git_log
check "cancel: command line untouched" 0 $__did_replace
check "cancel: still repaints" 1 $__repaints
set -g __fzf_ret 0

mkdir -p $sandbox/notrepo
cd $sandbox/notrepo
__reset_cl
set -l err (_fzf_search_git_log 2>&1 >/dev/null)
check "outside a repo: error on stderr" '_fzf_search_git_log: Not in a git repository.' "$err"
check "outside a repo: fzf not launched" 0 $__fzf_called
check "outside a repo: still repaints" 1 $__repaints
cd $sandbox

# ---- _fzf_search_history ---------------------------------------------------
section "_fzf_search_history: time prefix stripped, multi-line kept"

# History itself is a builtin and cannot be stubbed; private mode skips the
# merge so no history file is read or written. The fzf stub ignores the
# history it is fed and prints canned NUL-separated selections.
set -g fish_private_mode 1
set -g __hist_out
function _fzf_wrapper
    set -g __fzf_called 1
    set -g __fzf_args $argv
    command cat >/dev/null
    test (count $__hist_out) -gt 0; and printf '%s\0' $__hist_out
    return $__fzf_ret
end

__reset_cl
set -g __tok 'git st'
set -g __hist_out '09-01 10:00:00 │ echo "a │ b"; rm -- x'
_fzf_search_history
check "prefix stripped, inner │ kept" 'echo "a │ b"; rm -- x' "$__replaced"
check "whole command line passed as --query" 'git st' (__fzf_opt --query=)
check "NUL-safe fzf flags" true (contains -- --read0 $__fzf_args; and contains -- --print0 $__fzf_args; and echo true; or echo false)

__reset_cl
set -g __hist_out '09-01 10:00:00 │ for i in 1 2
    echo $i
end' '09-02 11:00:00 │ ls'
_fzf_search_history
check "multi-line entry survives (joined back by line)" 'for i in 1 2
    echo $i
end
ls' "$(string join \n -- $__replaced)"

__reset_cl
set -g __hist_out
set -g __fzf_ret 130
_fzf_search_history
check "cancel: command line untouched" 0 $__did_replace
check "cancel: still repaints" 1 $__repaints
set -g __fzf_ret 0
set -e fish_private_mode

# ---- _fzf_search_processes -------------------------------------------------
section "_fzf_search_processes: pids from the selection"

set -l psbin $sandbox/psbin
__stub $psbin ps 0 "printf '%s\\n' '    PID COMMAND' '    101 /usr/bin/foo --bar' '    202 sleep 1'"
set -l saved_path $PATH
set -gx PATH $psbin $PATH

function _fzf_wrapper
    set -g __fzf_called 1
    set -g __fzf_args $argv
    command cat >$sandbox/fzf.stdin
    set -l in (command cat $sandbox/fzf.stdin)
    for i in $__pick
        printf '%s\n' $in[$i]
    end
    return $__fzf_ret
end

__reset_cl
set -g __tok sle
set -g __pick 2 3
_fzf_search_processes
check "multi pick: pids joined by spaces" "101 202" "$__replaced"
check "ps called as ps -A -opid,command" "-A -opid,command" "$(__args ps | string join ' ')"
set -l qi (contains -i -- --query $__fzf_args)
check "current token passed as --query" sle $__fzf_args[(math $qi + 1)]
check "preview uses the resolved ps" true (string match -q -- "$psbin/ps -o *" (__fzf_opt --preview=); and echo true; or echo false)

__reset_cl
set -g __fzf_ret 1
_fzf_search_processes
check "cancel: command line untouched" 0 $__did_replace
check "cancel: still repaints" 1 $__repaints
set -g __fzf_ret 0
set -g __pick 1
set -gx PATH $saved_path

# ---- __fzf_inline_picker ---------------------------------------------------
section "__fzf_inline_picker: @@ path insertion"

function commandline
    set -g __cl_calls $__cl_calls (string join ' ' -- $argv)
    if test "$argv" = -t
        printf '%s\n' $__tok
    end
end
set -g __sel
function _fzf_wrapper
    set -g __fzf_called 1
    set -g __fzf_args $argv
    command cat >/dev/null
    test (count $__sel) -gt 0; and printf '%s\n' $__sel
end

set -l fdbin $sandbox/fdbin
__stub $fdbin fdfind 0 "echo 'some file'"
__stub $fdbin fd 0
set -gx PATH $fdbin $saved_path
set -g fzf_fd_opts --hidden

set -g __cl_calls
set -g __fzf_called 0
set -g __tok foo
__fzf_inline_picker
check "token is not @: a literal @ is inserted" "-t|-i @" (string join '|' -- $__cl_calls)
check "token is not @: fzf not launched" 0 $__fzf_called

set -g __cl_calls
set -g __tok @
set -g __sel "dir/it's \$HOME; touch PWNED_ip"
__reset_log
__fzf_inline_picker
set -l inserted (string replace -r '^-t -- ' '' -- $__cl_calls[2])
check "fdfind preferred, with color and fzf_fd_opts" "--color=always --hidden" "$(__args fdfind | string join ' ')"
check "preview wired to _fzf_preview_file" "_fzf_preview_file {}" (__fzf_opt --preview=)
check "selection inserted fish-escaped (round-trips as one arg)" "$__sel" (fish --no-config -c "printf '%s\n' $inserted")
check "inserted text never ran its payload" false (test -e PWNED_ip; and echo true; or echo false)
check "repaint after insertion" "-f repaint" "$__cl_calls[-1]"

set -g __cl_calls
set -g __sel
__fzf_inline_picker
check "nothing selected: @ becomes @@" "-t -- @@" "$__cl_calls[2]"

set -e fzf_fd_opts
set -gx PATH $saved_path
functions -e commandline _fzf_wrapper __reset_cl __fzf_opt

# ---- _fzf_configure_bindings_help ------------------------------------------
section "_fzf_configure_bindings_help: matches fzf_configure_bindings"

set -l help (_fzf_configure_bindings_help)
check "help: status 0" 0 $status
check "help: starts with USAGE" USAGE: "$help[1]"
set -l spec_line (string match -r -- "options_spec .*" < $repo_root/functions/fzf_configure_bindings.fish)
set -l documented (string match -rg -- '\|\s+(--[a-z_]+)\s*$' $help)
check "help documents six command options" 6 (count $documented)
set -l undocumented
for opt in $documented
    set -l name (string sub -s 3 -- $opt)
    string match -q -- "*'$name=?'*" $spec_line; or set -a undocumented $opt
end
check "every documented option exists in the argparse spec" "" "$undocumented"

set -lx CI true
check "fzf_configure_bindings --help prints this help" "$help" (fzf_configure_bindings --help | string join ' ')
set -l bad (fzf_configure_bindings --bogus 2>/dev/null)
check "invalid option: status 2" 2 $status
check "invalid option: help on stdout" "$help" "$bad"
set -e CI

# ---- clipboard bridge ------------------------------------------------------
section "_fish_clipboard_copy / _fish_clipboard_paste: provider fallback"

# Each case gives the function a $PATH holding only stub providers, so the
# real clipboard is unreachable.
function __clip_bin --argument-names dir
    for name in $argv[2..-1]
        __stub $dir $name 0 "'$real_cat' >'$logdir/$name.stdin'; echo PASTED-$name"
    end
end
function __stdin_of --argument-names name
    command cat $logdir/$name.stdin
end

set -l cb $sandbox/clip_all
__clip_bin $cb wl-copy wl-paste xclip win32yank.exe
__reset_log
printf 'line one\nline two\n' | __with_path $cb _fish_clipboard_copy >/dev/null
check "copy: wl-copy preferred" "line one|line two" (string join '|' (__stdin_of wl-copy))
check "copy: xclip not touched when wl-copy exists" false (__was_run xclip)
check "paste: wl-paste with passthrough args" "PASTED-wl-paste|--primary" (__with_path $cb _fish_clipboard_paste --primary </dev/null)"|"(__args wl-paste)

set -l cb $sandbox/clip_x
__clip_bin $cb xclip
__reset_log
echo data | __with_path $cb _fish_clipboard_copy >/dev/null
check "copy: xclip clipboard selection" "-selection clipboard" "$(__args xclip | string join ' ')"
check "copy: xclip received stdin" data (__stdin_of xclip)
__reset_log
__with_path $cb _fish_clipboard_paste -t text/plain </dev/null >/dev/null
check "paste: xclip -o plus passthrough args" "-selection clipboard -o -t text/plain" "$(__args xclip | string join ' ')"

set -l cb $sandbox/clip_win
__clip_bin $cb win32yank.exe
__reset_log
echo data | __with_path $cb _fish_clipboard_copy >/dev/null
check "copy: win32yank -i --crlf" "-i --crlf" "$(__args win32yank.exe | string join ' ')"
__reset_log
__with_path $cb _fish_clipboard_paste </dev/null >/dev/null
check "paste: win32yank -o --lf" "-o --lf" "$(__args win32yank.exe | string join ' ')"

set -l cb $sandbox/clip_fail
__stub $cb wl-copy 4
__stub $cb wl-paste 3
echo data | __with_path $cb _fish_clipboard_copy
check "copy: provider failure status propagates" 4 $status
__with_path $cb _fish_clipboard_paste </dev/null
check "paste: provider failure status propagates" 3 $status

set -l cb $sandbox/clip_none
mkdir -p $cb
set -l err (__with_path $cb _fish_clipboard_copy </dev/null 2>&1 >/dev/null)
check "copy: no provider -> status 1" 1 $status
check "copy: no provider -> error on stderr" true (string match -q 'Error: No clipboard provider*' -- $err; and echo true; or echo false)
set -l err (__with_path $cb _fish_clipboard_paste 2>&1 >/dev/null)
check "paste: no provider -> status 1" 1 $status
check "paste: no provider -> error on stderr" true (string match -q 'Error: No clipboard provider*' -- $err; and echo true; or echo false)

cd $start
command rm -rf $sandbox
report
