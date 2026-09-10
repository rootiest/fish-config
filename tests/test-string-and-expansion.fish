#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx TERM xterm-256color
set -g __fish_config_dir $repo_root 2>/dev/null; or true

# Ensure data/words is reachable via __fish_config_dir in isolated runs
if not test -d "$__fish_config_dir/data/words"
    mkdir -p "$__fish_config_dir/data"
    ln -sf "$repo_root/data/words" "$__fish_config_dir/data/words"
end

# -----------------------------------------------------------------------------
# rand_string: Components
# -----------------------------------------------------------------------------
section "rand_string: components"

check "literal component" FOO (rand_string literal=FOO)
check "string component" BAR (rand_string string=BAR)

set -l out_digits4 (rand_string digits=4)
check "digits=4 returns 4 digits" true (string match -qr '^\d{4}$' -- "$out_digits4"; and echo true; or echo false)

set -l out_digits1 (rand_string digits=1)
check "digits=1 returns 1 digit" true (string match -qr '^\d$' -- "$out_digits1"; and echo true; or echo false)

set -l out_digits_inv (rand_string digits=abc)
check "digits=non-numeric defaults to 1 digit" true (string match -qr '^\d$' -- "$out_digits_inv"; and echo true; or echo false)

set -l out_color (rand_string color)
check "category color generates non-empty word" true (test -n "$out_color"; and echo true; or echo false)

set -l out_animal (rand_string animal)
check "category animal generates non-empty word" true (test -n "$out_animal"; and echo true; or echo false)

set -l out_noun (rand_string noun)
check "category noun generates non-empty word" true (test -n "$out_noun"; and echo true; or echo false)

set -l out_verb (rand_string verb)
check "category verb generates non-empty word" true (test -n "$out_verb"; and echo true; or echo false)

set -l out_adj (rand_string adjective)
check "category adjective generates non-empty word" true (test -n "$out_adj"; and echo true; or echo false)

set -l out_name (rand_string name)
check "category name generates non-empty word" true (test -n "$out_name"; and echo true; or echo false)

# -----------------------------------------------------------------------------
# rand_string: Separators
# -----------------------------------------------------------------------------
section "rand_string: separators"

check "default separator is dash" A-B (rand_string literal=A literal=B)
check "--separator=underscore" A_B (rand_string --separator=underscore literal=A literal=B)
check "--separator=dot" "A.B" (rand_string --separator=dot literal=A literal=B)
check "--separator=none" AB (rand_string --separator=none literal=A literal=B)
check "--separator=empty" AB (rand_string --separator=empty literal=A literal=B)
check "-s dot" "A.B" (rand_string -s dot literal=A literal=B)
check "-s underscore" A_B (rand_string -s underscore literal=A literal=B)
check "-s none" AB (rand_string -s none literal=A literal=B)
check "custom literal separator ::" "A::B" (rand_string --separator=:: literal=A literal=B)

set -l out_multi (rand_string literal=test --separator=underscore literal=part digits=2)
check "multi-component with separators" true (string match -qr '^test_part_\d{2}$' -- "$out_multi"; and echo true; or echo false)

# -----------------------------------------------------------------------------
# rand_string: Casing
# -----------------------------------------------------------------------------
section "rand_string: casing"

check "--case=upper produces uppercase" true (string match -qr '^[A-Z]+$' -- (rand_string --case=upper color); and echo true; or echo false)
check "--case=lower produces lowercase" true (string match -qr '^[a-z]+$' -- (rand_string --case=lower color); and echo true; or echo false)
check "--case=title produces titlecase" true (string match -qr '^[A-Z][a-z]+$' -- (rand_string --case=title color); and echo true; or echo false)

check "-c upper flag" true (string match -qr '^[A-Z]+$' -- (rand_string -c upper animal); and echo true; or echo false)
check "-c lower flag" true (string match -qr '^[a-z]+$' -- (rand_string -c lower animal); and echo true; or echo false)
check "-c title flag" true (string match -qr '^[A-Z][a-z]+$' -- (rand_string -c title animal); and echo true; or echo false)

check "literal preserves casing with --case=upper" foo (rand_string --case=upper literal=foo)
check "literal preserves casing with --case=lower" FOO (rand_string --case=lower literal=FOO)
check "literal preserves casing with --case=title" foo (rand_string --case=title literal=foo)

# -----------------------------------------------------------------------------
# rand_string: Errors and Help
# -----------------------------------------------------------------------------
section "rand_string: errors and help"

rand_string nonexistent_cat_xyz >/dev/null 2>&1
check "missing category returns 1" 1 $status

set -l err_msg (rand_string nonexistent_cat_xyz 2>&1 >/dev/null)
check "missing category reports error on stderr" true (string match -qr 'unknown category' -- "$err_msg"; and echo true; or echo false)

rand_string -h >/dev/null 2>&1
check "-h returns 0" 0 $status

set -l help_h (rand_string -h)
check "-h displays usage" true (string match -qr 'Usage:' -- "$help_h"; and echo true; or echo false)

rand_string --help >/dev/null 2>&1
check "--help returns 0" 0 $status

set -l help_long (rand_string --help)
check "--help displays usage" true (string match -qr 'Usage:' -- "$help_long"; and echo true; or echo false)

# -----------------------------------------------------------------------------
# Mock commandline infrastructure
# -----------------------------------------------------------------------------
set -g mock_cmd_buffer ""
set -g mock_cmd_cursor 0
set -g mock_cmd_token ""
set -g mock_cmd_inserted ""
set -g mock_cmd_in_search 0

function commandline
    if test (count $argv) -eq 0
        echo -n "$mock_cmd_buffer"
        return 0
    end

    switch $argv[1]
        case -C
            if test (count $argv) -ge 2
                set -g mock_cmd_cursor $argv[2]
            else
                echo -n "$mock_cmd_cursor"
            end
            return 0
        case -r
            if test (count $argv) -ge 2
                set -g mock_cmd_buffer "$argv[2]"
            else
                set -g mock_cmd_buffer ""
            end
            return 0
        case --
            if test (count $argv) -ge 2
                set -g mock_cmd_buffer "$argv[2]"
            else
                set -g mock_cmd_buffer ""
            end
            return 0
        case -i --insert
            if test (count $argv) -ge 2
                set -g mock_cmd_inserted "$argv[2]"
                set -g mock_cmd_buffer "$mock_cmd_buffer$argv[2]"
            end
            return 0
        case --search-field
            if contains -- --insert $argv
                set -l idx (contains -i -- --insert $argv)
                set -l val $argv[(math $idx + 1)]
                set -g mock_cmd_inserted "$val"
                set -g mock_cmd_buffer "$mock_cmd_buffer$val"
                return 0
            else
                test "$mock_cmd_in_search" -eq 1
                return $status
            end
        case -t --current-token
            if test (count $argv) -ge 2
                set -l old_tok "$mock_cmd_token"
                set -g mock_cmd_token "$argv[2]"
                if test -n "$old_tok"
                    set -g mock_cmd_buffer (string replace -- "$old_tok" "$argv[2]" "$mock_cmd_buffer")
                else
                    set -g mock_cmd_buffer "$mock_cmd_buffer$argv[2]"
                end
            else
                echo -n "$mock_cmd_token"
            end
            return 0
    end
end

function set_test_history --argument-names cmd
    set -l session "test_hist_"(random)
    set -l hist_dir ""
    if test -n "$XDG_DATA_HOME"
        set hist_dir "$XDG_DATA_HOME/fish"
    else
        set hist_dir "$HOME/.local/share/fish"
    end
    mkdir -p "$hist_dir"
    set -l hist_file "$hist_dir/"$session"_history"
    echo "- cmd: $cmd" >"$hist_file"
    echo "  when: "(date +%s) >>"$hist_file"
    set -g fish_history "$session"
    set -g _last_test_hist_file "$hist_file"
end

function cleanup_test_history
    if set -q _last_test_hist_file; and test -f "$_last_test_hist_file"
        rm -f "$_last_test_hist_file"
    end
end

# -----------------------------------------------------------------------------
# _replace_command_token
# -----------------------------------------------------------------------------
section _replace_command_token

set mock_cmd_buffer "git status"
set mock_cmd_cursor -1
_replace_command_token
check "git status: buffer replaces command token" " status" "$mock_cmd_buffer"
check "git status: cursor placed at 0" 0 "$mock_cmd_cursor"

set mock_cmd_buffer "sudo rm -rf /tmp"
set mock_cmd_cursor -1
_replace_command_token
check "sudo rm -rf /tmp: buffer preserves sudo and replaces command" "sudo  -rf /tmp" "$mock_cmd_buffer"
check "sudo rm -rf /tmp: cursor placed at 5" 5 "$mock_cmd_cursor"

set mock_cmd_buffer "sudo systemctl status nginx"
set mock_cmd_cursor -1
_replace_command_token
check "sudo systemctl status: buffer preserves sudo" "sudo  status nginx" "$mock_cmd_buffer"
check "sudo systemctl status: cursor placed at 5" 5 "$mock_cmd_cursor"

set mock_cmd_buffer "python -m unittest"
set mock_cmd_cursor -1
_replace_command_token
check "python -m unittest: buffer replaces command token" " -m unittest" "$mock_cmd_buffer"
check "python -m unittest: cursor placed at 0" 0 "$mock_cmd_cursor"

set mock_cmd_buffer ls
set mock_cmd_cursor -1
_replace_command_token
check "single token ls: buffer becomes single space" " " "$mock_cmd_buffer"
check "single token ls: cursor placed at 0" 0 "$mock_cmd_cursor"

set mock_cmd_buffer "sudo reboot"
set mock_cmd_cursor -1
_replace_command_token
check "sudo reboot: buffer becomes sudo with two spaces" "sudo  " "$mock_cmd_buffer"
check "sudo reboot: cursor placed at 5" 5 "$mock_cmd_cursor"

# -----------------------------------------------------------------------------
# __substitute_typo
# -----------------------------------------------------------------------------
section __substitute_typo

set_test_history 'git commit -m "feat"'
set mock_cmd_buffer "^feat^fix"
set mock_cmd_inserted ""
__substitute_typo
check "substitute ^feat^fix in git commit" 'git commit -m "fix"' "$mock_cmd_buffer"

set_test_history "docker run -d nginx"
set mock_cmd_buffer "^nginx^redis"
set mock_cmd_inserted ""
__substitute_typo
check "substitute ^nginx^redis in docker run" "docker run -d redis" "$mock_cmd_buffer"

set_test_history "echo foo foo"
set mock_cmd_buffer "^foo^bar"
set mock_cmd_inserted ""
__substitute_typo
check "substitute replaces all occurrences" "echo bar bar" "$mock_cmd_buffer"

set_test_history "git checkout main feat"
set mock_cmd_buffer "^feat^"
set mock_cmd_inserted ""
__substitute_typo
check "substitute ^feat^ with empty string deletes token" "git checkout main " "$mock_cmd_buffer"

set_test_history "git status"
set mock_cmd_buffer "^"
set mock_cmd_inserted ""
__substitute_typo
check "lone caret inserts literal caret" "^" "$mock_cmd_inserted"
check "lone caret buffer retains caret" "^^" "$mock_cmd_buffer"

set_test_history "git status"
set mock_cmd_buffer "git log"
set mock_cmd_inserted ""
__substitute_typo
check "non-matching buffer inserts literal caret" "^" "$mock_cmd_inserted"

cleanup_test_history

# -----------------------------------------------------------------------------
# _puffer_fish_expand_dot
# -----------------------------------------------------------------------------
section _puffer_fish_expand_dot

set mock_cmd_token ".."
set mock_cmd_inserted ""
set mock_cmd_buffer ""
set mock_cmd_in_search 0
_puffer_fish_expand_dot
check "token .. inserts /.." "/.." "$mock_cmd_inserted"

set mock_cmd_token "../.."
set mock_cmd_inserted ""
set mock_cmd_buffer ""
set mock_cmd_in_search 0
_puffer_fish_expand_dot
check "token ../.. inserts /.." "/.." "$mock_cmd_inserted"

set mock_cmd_token "../../.."
set mock_cmd_inserted ""
set mock_cmd_buffer ""
set mock_cmd_in_search 0
_puffer_fish_expand_dot
check "token ../../.. inserts /.." "/.." "$mock_cmd_inserted"

set mock_cmd_token "."
set mock_cmd_inserted ""
set mock_cmd_buffer ""
set mock_cmd_in_search 0
_puffer_fish_expand_dot
check "token . inserts ." "." "$mock_cmd_inserted"

set mock_cmd_token "..."
set mock_cmd_inserted ""
set mock_cmd_buffer ""
set mock_cmd_in_search 0
_puffer_fish_expand_dot
check "token ... inserts ." "." "$mock_cmd_inserted"

set mock_cmd_token foo
set mock_cmd_inserted ""
set mock_cmd_buffer ""
set mock_cmd_in_search 0
_puffer_fish_expand_dot
check "token foo inserts ." "." "$mock_cmd_inserted"

set mock_cmd_token ".."
set mock_cmd_inserted ""
set mock_cmd_buffer ""
set mock_cmd_in_search 1
_puffer_fish_expand_dot
check "search field mode inserts . even if token is .." "." "$mock_cmd_inserted"

# -----------------------------------------------------------------------------
# _puffer_fish_expand_bang
# -----------------------------------------------------------------------------
section _puffer_fish_expand_bang

set_test_history "cargo test --release"

set mock_cmd_token "!"
set mock_cmd_buffer "!"
set mock_cmd_inserted ""
set mock_cmd_in_search 0
_puffer_fish_expand_bang
check "token ! expands to history[1]" "cargo test --release" "$mock_cmd_token"
check "token ! updates buffer" "cargo test --release" "$mock_cmd_buffer"

set mock_cmd_token "!"
set mock_cmd_buffer "sudo !"
set mock_cmd_inserted ""
set mock_cmd_in_search 0
_puffer_fish_expand_bang
check "sudo ! expands token to history[1]" "sudo cargo test --release" "$mock_cmd_buffer"

set mock_cmd_token git
set mock_cmd_buffer git
set mock_cmd_inserted ""
set mock_cmd_in_search 0
_puffer_fish_expand_bang
check "non-bang token inserts literal !" "!" "$mock_cmd_inserted"

set mock_cmd_token ""
set mock_cmd_buffer ""
set mock_cmd_inserted ""
set mock_cmd_in_search 0
_puffer_fish_expand_bang
check "empty token inserts literal !" "!" "$mock_cmd_inserted"

set mock_cmd_token "!"
set mock_cmd_buffer ""
set mock_cmd_inserted ""
set mock_cmd_in_search 1
_puffer_fish_expand_bang
check "search field mode inserts literal !" "!" "$mock_cmd_inserted"

cleanup_test_history

# Unshadow commandline builtin
functions -e commandline

report
