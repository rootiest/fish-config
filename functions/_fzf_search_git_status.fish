function _fzf_search_git_status --description "Search the output of git status. Replace the current token with the selected file paths."
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo '_fzf_search_git_status: Not in a git repository.' >&2
    else
        set -f preview_cmd '_fzf_preview_changed_file {}'
        if set --query fzf_diff_highlighter
            set preview_cmd "$preview_cmd | $fzf_diff_highlighter"
        end

        set -f selected_paths (
            # Pass configuration color.status=always to force status to use colors even though output is sent to a pipe
            git -c color.status=always status --short |
            _fzf_wrapper --ansi \
                --multi \
                --prompt="Git Status> " \
                --query=(commandline --current-token) \
                --preview=$preview_cmd \
                --nth="2.." \
                $fzf_git_status_opts
        )
        if test $status -eq 0
            # git status --short only C-quotes names containing a double quote, a backslash or control
            # characters; names such as a;b or a$(b) come through verbatim. Whatever git did, re-escape the
            # real name for fish so the inserted text can never run anything when the user presses Enter.
            set -f cleaned_paths

            for path in $selected_paths
                set -l selected_path
                if test (string sub --length 1 $path) = R
                    # path has been renamed and looks like "R LICENSE -> LICENSE.md"
                    # extract the path to use from after the arrow
                    set selected_path (string split -- "-> " $path)[-1]
                else
                    set selected_path (string sub --start=4 $path)
                end
                # Undo git's "..." quoting (only \" and \\ matter here) before escaping
                if string match --quiet --regex -- '^".*"$' $selected_path
                    set selected_path (string sub --start 2 --length (math (string length -- $selected_path) - 2) -- $selected_path |
                        string replace --all --regex -- '\\\\(["\\\\])' '$1')
                end
                set --append cleaned_paths (string escape -- $selected_path)
            end

            commandline --current-token --replace -- (string join ' ' $cleaned_paths)
        end
    end

    commandline --function repaint
end
