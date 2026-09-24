# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# DEPENDENCIES
#   curl, md5sum, md5, gitignore-scrub
#
# CLASSIFICATION
#   self-limiting(grep,cat), network, blocking-prompt
#
# SYNOPSIS
#   gi [-h] [-b] [-p] [-o] [-s] [-f] [-c TEMPLATE] [-l] [targets...]
#
# DESCRIPTION
#   Generates .gitignore content by querying the gitignore.io API. Appends
#   results to the repository's .gitignore with MD5-based deduplication —
#   patterns already present are not re-appended — or prints to stdout with
#   -o/--stdout. Boilerplate mode uses $GITIGNORE_BOILERPLATE if set, a
#   -c/--custom template if given, or falls back to the bundled standard
#   template (data/gi/boilerplate.gitignore) when neither is configured.
#   Supports generic boilerplate and interactive prompt modes.
#
# ARGUMENTS
#   -h, --help         Show help message
#   -d, --description  Show the function description
#   -l, --list         List all supported targets from the API
#   -b, --boilerplate  Append boilerplate (implied by -c)
#   -p, --prompt       Prompt for patterns to append
#   -o, --stdout       Print generated content to stdout instead of .gitignore
#   -s, --silent       Suppress progress output (errors and prompts still show)
#   -f, --force        Bypass prompts, proceeding with the default action
#   -c, --custom PATH  Use PATH as the boilerplate template instead of
#                       $GITIGNORE_BOILERPLATE
#   targets            Comma- or space-separated list of language/tool names
#
# EXIT STATUS
#   0  Patterns appended, or resolved with -o/--stdout or -l/--list
#   1  Not in a git repository or API fetch failed
#
# RETURNS
#   With -o/--stdout, the fetched .gitignore pattern text, printed to stdout.
#   With -l/--list, the supported target list, printed to stdout.
#
# EXAMPLE
#   gi python,venv
#   gi -b -p
#   gi -o node > .gitignore
#   gi -f              # skip prompt, proceed with no patterns
#   gi -c ~/my-template.gitignore
function gi --description 'Generate .gitignore files using the gitignore.io API'
    argparse h/help d/description l/list b/boilerplate p/prompt o/stdout s/silent f/force c/custom= -- $argv
    or return 1

    if set -q _flag_help
        __fish_palette
        echo "$c_head""Usage:$c_reset $c_cmd""gi$c_reset $c_arg""[TARGETS...]$c_reset $c_arg""[FLAGS]$c_reset"
        echo ""
        echo "$c_head""Arguments:$c_reset"
        echo "  $c_arg""TARGETS$c_reset       Comma-separated list of languages or tools"
        echo "                 $c_dim""e.g. c++,neovim,archlinux$c_reset"
        echo ""
        echo "$c_head""Flags:$c_reset"
        echo "  $c_flag-h, --help        $c_reset Show this help message"
        echo "  $c_flag-d, --description $c_reset Show the Fish function description"
        echo "  $c_flag-l, --list        $c_reset List all supported targets from the API"
        echo "  $c_flag-b, --boilerplate $c_reset Append boilerplate (implied by "$c_flag"-c$c_reset)"
        echo "  $c_flag-p, --prompt      $c_reset Prompt for patterns and append them to .gitignore"
        echo "  $c_flag-o, --stdout      $c_reset Print generated content to stdout instead of .gitignore"
        echo "  $c_flag-s, --silent      $c_reset Suppress progress output (errors and prompts still show)"
        echo "  $c_flag-f, --force       $c_reset Bypass prompts, proceeding with the default action"
        echo "  $c_flag-c, --custom      $c_reset $c_arg""PATH$c_reset Use PATH as the boilerplate template"
        echo "                       $c_dim""instead of \$GITIGNORE_BOILERPLATE$c_reset"
        echo ""
        echo "$c_head""Boilerplate source (in priority order):$c_reset"
        echo "  1. "$c_flag"-c/--custom$c_reset PATH, if given"
        echo "  2. "$c_arg"\$GITIGNORE_BOILERPLATE$c_reset, if set"
        echo "  3. "$c_dim"the bundled standard template$c_reset"
        echo ""
        echo "$c_head""Examples:$c_reset"
        echo "  $c_cmd""gi$c_reset                      $c_dim""# Append boilerplate and prompt for patterns (default)$c_reset"
        echo "  $c_cmd""gi -b$c_reset                   $c_dim""# Append boilerplate only$c_reset"
        echo "  $c_cmd""gi -p$c_reset                   $c_dim""# Prompt for patterns and append to .gitignore$c_reset"
        echo "  $c_cmd""gi$c_reset $c_arg""c++$c_reset                  $c_dim""# Append C++ patterns to .gitignore$c_reset"
        echo "  $c_cmd""gi$c_reset $c_arg""python,venv$c_reset          $c_dim""# Append Python+venv patterns to .gitignore$c_reset"
        echo "  $c_cmd""gi -o$c_reset $c_arg""python,venv$c_reset       $c_dim""# Print Python+venv patterns to stdout$c_reset"
        echo "  $c_cmd""gi -f$c_reset                   $c_dim""# Skip prompt, proceed with no patterns$c_reset"
        echo "  $c_cmd""gi -c$c_reset $c_arg""~/my.gitignore$c_reset     $c_dim""# Append a custom boilerplate template$c_reset"
        echo "  $c_cmd""gi -l$c_reset | grep -i linux   $c_dim""# Search for specific OS support$c_reset"
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

    set -l silent_flag 0
    set -q _flag_silent; and set silent_flag 1

    # Determine which modes to run
    set -l do_boilerplate 0
    set -l do_prompt 0

    if set -q _flag_boilerplate; or set -q _flag_custom
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

    # Resolve git context for anything that writes to .gitignore.
    # --stdout never touches .gitignore, so it never needs a git repo.
    set -l gitignore_path ""
    set -l readable_path ""
    set -l needs_git 0
    if not set -q _flag_stdout
        if test $do_boilerplate -eq 1; or test $do_prompt -eq 1
            set needs_git 1
        else if set -q argv[1]
            set needs_git 1
        end
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

    # Boilerplate mode: resolve the template source, in priority order:
    #   1. -c/--custom PATH
    #   2. $GITIGNORE_BOILERPLATE
    #   3. the bundled standard template (data/gi/boilerplate.gitignore)
    if test $do_boilerplate -eq 1
        set -l boilerplate_path ""
        set -l boilerplate_ok 1

        if set -q _flag_custom
            if test -f "$_flag_custom"
                set boilerplate_path "$_flag_custom"
            else
                set_color red --bold
                echo "Error:" (set_color normal)"Custom boilerplate file not found at '$_flag_custom'" >&2
                set boilerplate_ok 0
            end
        else if set -q GITIGNORE_BOILERPLATE
            if test -f "$GITIGNORE_BOILERPLATE"
                set boilerplate_path "$GITIGNORE_BOILERPLATE"
            else
                set_color red --bold
                echo "Error:" (set_color normal)"Boilerplate file not found at '$GITIGNORE_BOILERPLATE'" >&2
                set boilerplate_ok 0
            end
        else
            if set -q __fish_config_dir
                set boilerplate_path "$__fish_config_dir/data/gi/boilerplate.gitignore"
            else
                set boilerplate_path "$HOME/.config/fish/data/gi/boilerplate.gitignore"
            end
            if not test -f "$boilerplate_path"
                set_color red --bold
                echo "Error:" (set_color normal)"Bundled default boilerplate missing at '$boilerplate_path'" >&2
                set boilerplate_ok 0
            else if not set -q _flag_silent
                set_color yellow --bold
                echo "Notice:" (set_color normal)"\$GITIGNORE_BOILERPLATE not set; using the bundled default template."
            end
        end

        if test $boilerplate_ok -eq 1
            if set -q _flag_stdout
                cat "$boilerplate_path"
            else
                set -l template_hash ""
                if command -q md5sum
                    set template_hash (md5sum "$boilerplate_path" | string split ' ')[1]
                else if command -q md5
                    set template_hash (md5 -q "$boilerplate_path")
                end

                set -l sig "# id: gitig-boilerplate-$template_hash"

                if test -f "$gitignore_path"; and grep -qF "$sig" "$gitignore_path"
                    if not set -q _flag_silent
                        set_color yellow --bold
                        echo "Notice:" (set_color normal)"Boilerplate already present in "(set_color cyan)"$readable_path"(set_color normal)"."
                    end
                else
                    printf "\n%s\n" "$sig" >>"$gitignore_path"
                    cat "$boilerplate_path" >>"$gitignore_path"
                    if not set -q _flag_silent
                        echo (set_color green)"✔"(set_color normal)" Appended boilerplate to "(set_color cyan)"$readable_path"(set_color normal)
                    end
                end
            end
        end
    end

    # Prompt mode: ask for patterns, fetch and dedup (or print) each one individually
    if test $do_prompt -eq 1
        set -l patterns ""
        if set -q _flag_force
            # Bypass the prompt: proceed with the default action (no patterns)
            set patterns ""
        else
            read -P "Enter gitignore patterns (comma-separated, e.g. python,vim): " patterns
            or return 0
        end
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
                if set -q _flag_stdout
                    echo "$content"
                else
                    __gi_append_dedup "$content" "$pattern" "$gitignore_path" "$readable_path" $silent_flag
                end
            end
        else if not set -q _flag_silent
            echo (set_color brblack)"No patterns selected. Skipping API fetch."(set_color normal)
        end
        test $needs_git -eq 1; and gitignore-scrub
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
                __gi_append_dedup "$content" "$target" "$gitignore_path" "$readable_path" $silent_flag
            end
        end
    end

    if test $needs_git -eq 1
        gitignore-scrub
    end
    return 0
end

# SYNOPSIS
#   __gi_append_dedup <content> <label> <gitignore_path> <readable_path> [silent]
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
#   silent          1 to suppress progress output, 0/omitted to show it
#
# EXAMPLE
#   __gi_append_dedup "$content" "python" "$root/.gitignore" "~/.gitignore" 0
function __gi_append_dedup
    set -l content $argv[1]
    set -l label $argv[2]
    set -l gitignore_path $argv[3]
    set -l readable_path $argv[4]
    set -l silent $argv[5]

    set -l content_hash ""
    if command -q md5sum
        set content_hash (echo "$content" | md5sum | string split ' ')[1]
    else if command -q md5
        set content_hash (echo "$content" | md5)
    end

    set -l sig "# id: gi-patterns-$content_hash"

    if test -f "$gitignore_path"; and grep -qF "$sig" "$gitignore_path"
        if test "$silent" != 1
            set_color yellow --bold
            echo "Notice:" (set_color normal)"$label patterns already present in "(set_color cyan)"$readable_path"(set_color normal)"."
        end
    else
        printf "\n%s\n%s\n" "$sig" "$content" >>"$gitignore_path"
        if test "$silent" != 1
            echo (set_color green)"✔"(set_color normal)" Appended $label patterns to "(set_color cyan)"$readable_path"(set_color normal)
        end
    end
end
