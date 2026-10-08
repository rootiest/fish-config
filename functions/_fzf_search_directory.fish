function _fzf_search_directory --description "Search the current directory. Replace the current token with the selected file paths."
    # Directly use fd binary to avoid output buffering delay caused by a fd alias, if any.
    # Debian-based distros install fd as fdfind and the fd package is something else, so
    # check for fdfind first. Fall back to "fd" for a clear error message.
    set -f fd_cmd (command -v fdfind || command -v fd  || echo "fd")
    set -f --append fd_cmd --color=always $fzf_fd_opts

    set -f fzf_arguments --multi --ansi $fzf_directory_opts
    set -f token (commandline --current-token)
    # Unquote the token, then expand a leading tilde (~) and $VAR references by hand.
    # Never eval the token: it is whatever text sits under the cursor, so $(...) or
    # (...) in it would run as a command. Anything else is kept literal.
    set -f unescaped_exp_token (string unescape -- $token 2>/dev/null; or printf '%s\n' $token)
    # a single-quoted token is literal by definition, so leave its $ alone
    if not string match -q -- "'*" $token
        set -f rest $unescaped_exp_token
        set -f unescaped_exp_token ''
        while set -l m (string match -r -- '^(.*?)\$([A-Za-z_][A-Za-z0-9_]*)(.*)$' $rest)
            set -l var_name $m[3]
            set -f unescaped_exp_token $unescaped_exp_token$m[2](string join ' ' -- $$var_name)
            set -f rest $m[4]
        end
        set -f unescaped_exp_token $unescaped_exp_token$rest
    end
    set -f unescaped_exp_token (string replace -r -- '^~(?=/|$)' $HOME $unescaped_exp_token)

    # If the current token is a directory and has a trailing slash,
    # then use it as fd's base directory.
    if string match --quiet -- "*/" $unescaped_exp_token && test -d "$unescaped_exp_token"
        set --append fd_cmd --base-directory=$unescaped_exp_token
        # use the directory name as fzf's prompt to indicate the search is limited to that directory
        set --prepend fzf_arguments --prompt="Directory $unescaped_exp_token> " --preview="_fzf_preview_file "(string escape -- $unescaped_exp_token)"{}"
        set -f file_paths_selected $unescaped_exp_token($fd_cmd 2>/dev/null | _fzf_wrapper $fzf_arguments)
    else
        set --prepend fzf_arguments --prompt="Directory> " --query="$unescaped_exp_token" --preview='_fzf_preview_file {}'
        set -f file_paths_selected ($fd_cmd 2>/dev/null | _fzf_wrapper $fzf_arguments)
    end

    if test $status -eq 0
        commandline --current-token --replace -- (string escape -- $file_paths_selected | string join ' ')
    end

    commandline --function repaint
end
