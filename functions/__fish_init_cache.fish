# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   bypasses-shadow(rm,mkdir,mv)
#
# SYNOPSIS
#   __fish_init_cache <name> <command> [<args>...]
#   __fish_init_cache --clear [<name>]
#
# DESCRIPTION
#   Sources a tool's generated shell init (for example "fzf --fish" or
#   "direnv hook fish") from an on-disk cache instead of forking the tool
#   on every shell start. The output of <command> is stored in
#   $XDG_CACHE_HOME/fish-config/init/<name>.fish (default ~/.cache) and
#   re-used while the tool's binary is unchanged.
#
#   The cache is keyed on everything the output can depend on: the resolved
#   path of <command>'s binary, that file's modification time, the full
#   <command> line, the running fish version and a format revision. Any
#   difference is a miss, so upgrading or replacing the tool, or switching
#   to another binary earlier on PATH, regenerates the entry. The key is
#   computed with fish builtins only, so a hit forks nothing.
#
#   Nothing here is ever fatal. The function returns 1, leaving the caller
#   to run its original "<command> | source" line, whenever caching cannot
#   be trusted: the opt-out is set, the binary cannot be resolved or
#   stat-ed, or the command fails, prints nothing or prints text that does
#   not parse. An unreadable, truncated or differently keyed cache file is
#   simply regenerated. A cache that cannot be written costs nothing but
#   the missed speed-up.
#
#   Set __fish_config_init_cache to an explicit falsy value (0, off, ...)
#   to disable the cache entirely, or run --clear to drop the entries.
#
# ARGUMENTS
#   name       Cache entry name; letters, digits, dot, underscore, dash.
#   command    Command (and arguments) whose stdout is a fish script. Its
#              first word must be an executable found on PATH.
#   --clear    Remove the cached entry <name>, or every entry when no name
#              is given.
#
# EXIT STATUS
#   0  The init was sourced (from the cache, or freshly generated)
#   1  Not sourced; the caller must fall back to running <command> itself
#   2  Usage error
#
# EXAMPLE
#   __fish_init_cache direnv direnv hook fish
#   or direnv hook fish | source
function __fish_init_cache --description 'Source a tool init script from a cache keyed on its binary'
    set -l cache_home $XDG_CACHE_HOME
    test -n "$cache_home"; or set cache_home "$HOME/.cache"
    set -l dir "$cache_home/fish-config/init"

    if test "$argv[1]" = --clear
        if test (count $argv) -ge 2
            string match -qr '^[A-Za-z0-9_.-]+$' -- $argv[2]; or return 2
            command rm -f -- "$dir/$argv[2].fish"
        else
            set -l files
            set files $dir/*.fish 2>/dev/null
            set -q files[1]; and command rm -f -- $files
        end
        return 0
    end

    if test (count $argv) -lt 2
        return 2
    end
    set -l name $argv[1]
    set -e argv[1]
    string match -qr '^[A-Za-z0-9_.-]+$' -- $name; or return 2

    # Explicit opt-out; unset (the default) keeps the cache on.
    __fish_variable_check __fish_config_init_cache
    test $status -eq 1; and return 1

    # Key: resolved binary, its mtime, the command line, the fish version and
    # the format revision. `path mtime` has one-second resolution, fine for a
    # package upgrade or a rebuilt binary.
    set -l bin (command -s -- $argv[1])
    or return 1
    set -l real (path resolve -- $bin[1])
    or return 1
    set -l mtime (path mtime -- $real)
    or return 1
    set -l key (string join '|' -- $real $mtime "$version" (string join ' ' -- $argv))
    set -l header "# fish-config init-cache v1 $key"
    set -l trailer '# fish-config init-cache end'
    set -l file "$dir/$name.fish"

    # Hit: first line equal to the expected key and the end marker as the
    # last line (an interrupted write has neither). `read` is used because
    # it is far cheaper on a 15 KB file than `string collect` plus a split.
    if test -f "$file"
        read -l first <"$file" 2>/dev/null
        and test "$first" = "$header"
        and read -z -l content <"$file" 2>/dev/null
        and string match -qr -- '\n# fish-config init-cache end\n$' "$content"
        and begin
            source "$file"
            return 0
        end
    end

    # Miss: generate, check that it parses, source it, then try to store it.
    # stderr is dropped because a failure falls back to the caller's own
    # run, which reports it. The parse check (one fork, paid by a miss only)
    # keeps unparsable output from being half-executed or ever cached; the
    # sourced script's own status says nothing, it is just its last
    # command's.
    set -l out ($argv 2>/dev/null)
    set -l generated $status
    if test $generated -ne 0; or test (count $out) -eq 0
        return 1
    end
    set -l fish_bin (status fish-path)
    printf '%s\n' $out | command $fish_bin --no-execute 2>/dev/null
    or return 1
    printf '%s\n' $out | source

    # Written beside the target and renamed into place, so a concurrent
    # shell never reads a partial file. A location that cannot be written
    # (read-only, not a directory) is skipped quietly.
    test -d "$dir"; or command mkdir -m 700 -p -- "$dir" 2>/dev/null
    if test -d "$dir" -a -w "$dir"; and not test -d "$file"
        set -l tmp "$file.$fish_pid"
        begin
            echo $header
            printf '%s\n' $out
            echo $trailer
        end >"$tmp"
        and command mv -f -- "$tmp" "$file"
        or begin
            test -e "$tmp"; and command rm -f -- "$tmp"
        end
    end
    return 0
end
