# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# SYNOPSIS
#   gi [-h] [-b] [-p] [-s] [-l] [targets...]
#
# DESCRIPTION
#   Generates .gitignore content by querying the gitignore.io API. Appends
#   results to the repository's .gitignore with MD5-based deduplication —
#   patterns already present are not re-appended — or prints to stdout with
#   -s. Supports generic boilerplate and interactive prompt modes.
#
# ARGUMENTS
#   -h, --help         Show help message
#   -d, --description  Show the function description
#   -l, --list         List all supported targets from the API
#   -b, --boilerplate  Append boilerplate from $GITIGNORE_BOILERPLATE
#   -p, --prompt       Prompt for patterns to append
#   -s, --stdout       Print API output to stdout instead of .gitignore
#   targets            Comma- or space-separated list of language/tool names
#
# EXIT STATUS
#   0  Patterns appended, or resolved with -s/--stdout or -l/--list
#   1  Not in a git repository or API fetch failed
#
# RETURNS
#   With -s/--stdout, the fetched .gitignore pattern text, printed to stdout.
#   With -l/--list, the supported target list, printed to stdout.
#
# EXAMPLE
#   gi python,venv
#   gi -b -p
#   gi -s node > .gitignore
function gi --description 'Generate .gitignore files using the gitignore.io API'
    argparse h/help d/description l/list b/boilerplate p/prompt s/stdout -- $argv
    or return 1

    if set -q _flag_help
        set_color --bold
        echo "Usage:"(set_color normal)" gi "(set_color cyan)"[TARGETS...]"(set_color yellow)" [FLAGS]"(set_color normal)
        echo ""
        set_color --bold
        echo "Arguments:"(set_color normal)
        echo "  "(set_color cyan)"TARGETS"(set_color normal)"       Comma-separated list of languages or tools"
        echo "                 "(set_color brblack)"e.g. c++,neovim,archlinux"(set_color normal)
        echo ""
        set_color --bold
        echo "Flags:"(set_color normal)
        echo "  "(set_color yellow)"-h, --help        "(set_color normal)" Show this help message"
        echo "  "(set_color yellow)"-d, --description "(set_color normal)" Show the Fish function description"
        echo "  "(set_color yellow)"-l, --list        "(set_color normal)" List all supported targets from the API"
        echo "  "(set_color yellow)"-b, --boilerplate "(set_color normal)" Append boilerplate from "(set_color cyan)"\$GITIGNORE_BOILERPLATE"(set_color normal)" to .gitignore"
        echo "  "(set_color yellow)"-p, --prompt      "(set_color normal)" Prompt for patterns and append them to .gitignore"
        echo "  "(set_color yellow)"-s, --stdout      "(set_color normal)" Print API output to stdout instead of appending to .gitignore"
        echo ""
        set_color --bold
        echo "Examples:"(set_color normal)
        echo "  "(set_color green)"gi"(set_color normal)"                      "(set_color brblack)"# Append boilerplate and prompt for patterns (default)"(set_color normal)
        echo "  "(set_color green)"gi -b"(set_color normal)"                   "(set_color brblack)"# Append boilerplate only"(set_color normal)
        echo "  "(set_color green)"gi -p"(set_color normal)"                   "(set_color brblack)"# Prompt for patterns and append to .gitignore"(set_color normal)
        echo "  "(set_color green)"gi"(set_color normal)" "(set_color cyan)"c++"(set_color normal)"                  "(set_color brblack)"# Append C++ patterns to .gitignore"(set_color normal)
        echo "  "(set_color green)"gi"(set_color normal)" "(set_color cyan)"python,venv"(set_color normal)"          "(set_color brblack)"# Append Python+venv patterns to .gitignore"(set_color normal)
        echo "  "(set_color green)"gi -s"(set_color normal)" "(set_color cyan)"python,venv"(set_color normal)"       "(set_color brblack)"# Print Python+venv patterns to stdout"(set_color normal)
        echo "  "(set_color green)"gi -l"(set_color normal)" | grep -i linux   "(set_color brblack)"# Search for specific OS support"(set_color normal)
        return 0
    end

    if set -q _flag_description
        functions -D gi
        return 0
    end

    if set -q _flag_list
        curl -sL https://www.toptal.com/developers/gitignore/api/list
        return 0
    end

    # Determine which modes to run
    set -l do_boilerplate 0
    set -l do_prompt 0

    if set -q _flag_boilerplate
        set do_boilerplate 1
    end
    if set -q _flag_prompt
        set do_prompt 1
    end

    # Default (no args, no interactive flags): run both boilerplate and prompt
    if not set -q argv[1]; and test $do_boilerplate -eq 0; and test $do_prompt -eq 0
        set do_boilerplate 1
        set do_prompt 1
    end

    # Resolve git context for anything that writes to .gitignore
    set -l gitignore_path ""
    set -l readable_path ""
    set -l needs_git 0
    if test $do_boilerplate -eq 1; or test $do_prompt -eq 1
        set needs_git 1
    else if set -q argv[1]; and not set -q _flag_stdout
        set needs_git 1
    end

    if test $needs_git -eq 1
        if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
            set_color red --bold
            echo "Error:" (set_color normal)"Not a git repository (or any parent directories)" >&2
            return 1
        end
        set -l git_root (git rev-parse --show-toplevel)
        set gitignore_path "$git_root/.gitignore"
        set readable_path (string replace -r "^$HOME" "~" $gitignore_path)
    end

    # Boilerplate mode
    if test $do_boilerplate -eq 1
        if not set -q GITIGNORE_BOILERPLATE
            set_color red --bold
            echo "Error:" (set_color normal)"\$GITIGNORE_BOILERPLATE environment variable is not defined" >&2
        else if not test -f "$GITIGNORE_BOILERPLATE"
            set_color red --bold
            echo "Error:" (set_color normal)"Boilerplate file not found at '$GITIGNORE_BOILERPLATE'" >&2
        else
            set -l template_hash ""
            if command -q md5sum
                set template_hash (md5sum "$GITIGNORE_BOILERPLATE" | string split ' ')[1]
            else if command -q md5
                set template_hash (md5 -q "$GITIGNORE_BOILERPLATE")
            end

            set -l sig "# id: gitig-boilerplate-$template_hash"

            if test -f "$gitignore_path"; and grep -qF "$sig" "$gitignore_path"
                set_color yellow --bold
                echo "Notice:" (set_color normal)"Boilerplate already present in "(set_color cyan)"$readable_path"(set_color normal)"."
            else
                printf "\n%s\n" "$sig" >>"$gitignore_path"
                cat "$GITIGNORE_BOILERPLATE" >>"$gitignore_path"
                echo (set_color green)"✔"(set_color normal)" Appended boilerplate to "(set_color cyan)"$readable_path"(set_color normal)
            end
        end
    end

    # Prompt mode: ask for patterns, fetch and dedup each one individually
    if test $do_prompt -eq 1
        read -P "Enter gitignore patterns (comma-separated, e.g. python,vim): " patterns
        or return 0
        set patterns (string trim -- $patterns)
        if test -n "$patterns"
            for pattern in (string split "," -- $patterns)
                set pattern (string trim -- $pattern)
                test -z "$pattern"; and continue
                set -l content (curl -f -sL "https://www.toptal.com/developers/gitignore/api/$pattern" | string collect)
                if test $status -ne 0
                    echo "Error: Failed to fetch gitignore for '$pattern'. Is the target spelled correctly?" >&2
                    continue
                end
                __gi_append_dedup "$content" "$pattern" "$gitignore_path" "$readable_path"
            end
        else
            echo (set_color brblack)"No patterns selected. Skipping API fetch."(set_color normal)
        end
        return 0
    end

    # Direct API call mode
    if set -q argv[1]
        set -l targets (string join "," $argv)

        if set -q _flag_stdout
            # stdout: single combined request, no dedup
            set -l content (curl -f -sL "https://www.toptal.com/developers/gitignore/api/$targets" | string collect)
            if test $status -ne 0
                echo "Error: Failed to fetch gitignore. Are the targets spelled correctly?" >&2
                return 1
            end
            echo "$content"
        else
            # append: fetch and dedup each pattern individually
            for target in (string split "," -- $targets)
                set target (string trim -- $target)
                test -z "$target"; and continue
                set -l content (curl -f -sL "https://www.toptal.com/developers/gitignore/api/$target" | string collect)
                if test $status -ne 0
                    echo "Error: Failed to fetch gitignore for '$target'. Is the target spelled correctly?" >&2
                    continue
                end
                __gi_append_dedup "$content" "$target" "$gitignore_path" "$readable_path"
            end
        end
    end
end

# SYNOPSIS
#   __gi_append_dedup <content> <label> <gitignore_path> <readable_path>
#
# DESCRIPTION
#   Appends gitignore content to a .gitignore file using MD5-based deduplication.
#   Skips the append if an identical content block is already present.
#
# ARGUMENTS
#   content         The gitignore pattern content to append
#   label           Human-readable label for the pattern set
#   gitignore_path  Absolute path to the .gitignore file
#   readable_path   Home-abbreviated path shown in output messages
#
# EXAMPLE
#   __gi_append_dedup "$content" "python" "$root/.gitignore" "~/.gitignore"
function __gi_append_dedup
    set -l content $argv[1]
    set -l label $argv[2]
    set -l gitignore_path $argv[3]
    set -l readable_path $argv[4]

    set -l content_hash ""
    if command -q md5sum
        set content_hash (echo "$content" | md5sum | string split ' ')[1]
    else if command -q md5
        set content_hash (echo "$content" | md5)
    end

    set -l sig "# id: gi-patterns-$content_hash"

    if test -f "$gitignore_path"; and grep -qF "$sig" "$gitignore_path"
        set_color yellow --bold
        echo "Notice:" (set_color normal)"$label patterns already present in "(set_color cyan)"$readable_path"(set_color normal)"."
    else
        printf "\n%s\n%s\n" "$sig" "$content" >>"$gitignore_path"
        echo (set_color green)"✔"(set_color normal)" Appended $label patterns to "(set_color cyan)"$readable_path"(set_color normal)
    end
end
