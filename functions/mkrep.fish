# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# DEPENDENCIES
#   _fish_mkdir_p, __fish_palette, _mkrep_say, _mkrep_verbose,
#   _mkrep_add_origin, _mkrep_default_remote_cmd, _mkrep_remote_url,
#   _mkrep_repo_exists, git
#
# CLASSIFICATION
#   bypasses-shadow(cd), destructive, network
#
# SYNOPSIS
#   mkrep [--cd | --no-cd] [--mkdir | --no-mkdir] [--git | --no-git]
#         [-c | --clean | --no-clean] [--strict] [-v | --verbose]
#         [-s | --silent] [--template <path>] [--branch <name>]
#         [--remote <url>] [--new-remote [<cmd>]] [--server <type>]
#         [--check-existing] [-y | --yes] [--name <name>] [-h | --help] <dir>
#
# DESCRIPTION
#   Creates a directory, cds into it, and git-inits it -- mkcd plus a git
#   repo in one step. All three actions are on by default and each has a
#   --no-* flag to skip it, plus a same-named flag to force it back on. If
#   both a flag and its --no- counterpart are given, --no- wins.
#
#   --clean removes an existing target directory before recreating it,
#   for a guaranteed-fresh start; --strict instead refuses to proceed if
#   the directory already exists. The two compose: --clean runs first, so
#   --clean --strict together is not a contradiction -- strict sees an
#   empty slot because clean just emptied it.
#
#   --remote links an already-existing remote (git remote add origin
#   <url>) -- it does not create anything. Linking is idempotent: an origin
#   already pointing at that URL is reported and accepted, so rerunning
#   mkrep against the same target, or pointing it at a checkout that is
#   already linked, succeeds instead of failing on "remote origin already
#   exists". An origin pointing somewhere else is an error, not a silent
#   repoint. --new-remote creates one first
#   by running a shell command template in the new repo directory, then
#   nothing further is needed since the template itself does the linking
#   (e.g. gh repo create {name} --source=. --remote=origin --push).
#   Three placeholders are substituted in a template: {name} (--name, or
#   the target directory's basename), {user} ($USER), and {server} (the
#   resolved server base URL, gitea/gitlab only). Pass a command after
#   --new-remote to use it for this call only; with no value it falls
#   back to $MKREP_REMOTE_CMD. --remote and --new-remote are mutually
#   exclusive, and either requires --git.
#
#   --server <type> (gitea, gitlab, or github) picks a host without an
#   explicit --remote/--new-remote: resolve its base URL from
#   $GITEA_URL/$GITEA_HOST (gitea) or $GITLAB_URL/$GITLAB_HOST (gitlab),
#   preferring the _URL form when both are set. _URL is used as-is and
#   must include its scheme (https://git.example.com); _HOST is bare
#   (git.example.com) and gets https:// prepended. Then run
#   $MKREP_REMOTE_CMD or that type's built-in default template. With no
#   --server, --remote, or --new-remote, $GIT_SERVER picks the type the
#   same way (invalid values are rejected the same as an invalid
#   --server) -- $GITEA_URL/$GITEA_HOST/$GITLAB_URL/$GITLAB_HOST only ever
#   supply the base URL, never the type on their own, so setting one for
#   an unrelated tool (an API token helper, say) can't turn a plain mkrep
#   call into a remote-creating one. This auto-detect path is silent (no
#   error) under --no-git; --server itself still requires --git, and
#   --server together with --remote or --new-remote is an error. Either
#   way, before creating anything mkrep checks whether
#   <user>/<name> already exists on that host: if so, it links to the
#   existing repo instead of creating one; if not, it creates the repo
#   and reports the new remote's URL. --check-existing runs just that
#   check and reports the result without creating or linking anything; it
#   requires a resolved server and is mutually exclusive with --remote
#   and --new-remote.
#
#   Creating a repository on a live forge is the only outward-facing thing
#   mkrep does, and on the $GIT_SERVER path an exported variable is all it
#   takes to reach it -- so a plain mkrep call, which reads as purely
#   local, would otherwise make a repo on a server without ever saying so.
#   That case therefore asks for confirmation first, defaulting to no.
#   Declining leaves the local repo in place with no remote and still
#   exits 0. Linking an existing repo is not affected, and neither is an
#   explicitly requested remote: --server, --remote and --new-remote all
#   say outright what they are going to do, so none of them prompts. Pass
#   --yes to skip the question. Where it cannot be asked -- a script, a
#   pipe, any non-interactive shell -- creation is skipped rather than
#   assumed, with a note on stderr naming the flags that would allow it.
#
# ARGUMENTS
#   <dir>            Directory to create and enter
#   --cd, --no-cd    Change into <dir> (default: --cd)
#   --mkdir, --no-mkdir
#                    Create <dir>, including missing parents (default: --mkdir)
#   --git, --no-git  Run git init in <dir> (default: --git)
#   -c, --clean      Remove <dir> first if it already exists
#   --no-clean       Leave an existing <dir> alone (default)
#   --strict         Fail if <dir> already exists (checked after --clean)
#   -v, --verbose    Print each step as it runs
#   -s, --silent     Suppress all output; overrides --verbose
#   --template <path>
#                    Passed through as git init --template=<path>
#   --branch <name>  Passed through as git init -b <name>
#   --remote <url>   Link an existing remote: git remote add origin <url>
#   --new-remote [<cmd>]
#                    Create + link a remote by running <cmd> (or
#                    $MKREP_REMOTE_CMD) in the new repo directory
#   --server <type>  Auto-create/link a remote on gitea, gitlab, or github
#   --check-existing Report whether the repo exists on the resolved
#                    server; creates or links nothing
#   -y, --yes        Create the remote without confirming, on the
#                    $GIT_SERVER path that would otherwise ask
#   --name <name>    {name} substitution for --new-remote/--server
#                    (default: <dir>'s basename)
#   -h, --help       Show this help message
#
# EXIT STATUS
#   0  All requested steps completed, or a $GIT_SERVER remote-create was
#      declined at the prompt (the local repo is still set up)
#   1  Bad arguments, or a step (mkdir, cd, git init, remote) failed
#
# EXAMPLE
#   mkrep ~/projects/my-new-repo
#   mkrep --clean --strict ~/projects/scratch
#   mkrep --remote git@git.example.com:me/foo.git ~/projects/foo
#   set -Ux MKREP_REMOTE_CMD 'gh repo create {name} --private --source=. --remote=origin --push'
#   mkrep --new-remote ~/projects/foo
#   set -gx GITEA_URL https://git.example.com
#   set -gx GIT_SERVER gitea
#   mkrep ~/projects/foo        # asks before creating the remote
#   mkrep --yes ~/projects/foo  # creates it without asking
#   mkrep --server gitlab --check-existing ~/projects/foo
#
#   Starting points for $MKREP_REMOTE_CMD, one per host CLI -- each assumes
#   that tool is already installed and authenticated, creates a private
#   repo under the caller's own account, and pushes it if there is
#   already a commit to push (mkrep itself only runs git init, so a
#   freshly created repo has none yet -- pushing an unborn HEAD is a
#   guaranteed error regardless of the remote, so the push is skipped
#   rather than attempted). These are also mkrep's built-in defaults for
#   --server/$GIT_SERVER when $MKREP_REMOTE_CMD is unset. gh supports a
#   one-shot --source/--remote/--push; glab and tea's create commands do
#   not, so they are chained with the git commands that do the linking:
#     GitHub (gh):   gh repo create {name} --private --source=. --remote=origin --push
#     GitLab (glab): glab repo create {name} --private --skipGitInit && git remote add origin {server}/{user}/{name}.git && if git rev-parse --verify -q HEAD >/dev/null 2>&1; git push -u origin HEAD; end
#     Gitea (tea):   tea repos create --name {name} --private && git remote add origin {server}/{user}/{name}.git && if git rev-parse --verify -q HEAD >/dev/null 2>&1; git push -u origin HEAD; end
function mkrep --description 'Create a directory, cd into it, and git init it'
    __fish_palette

    argparse h/help cd no-cd mkdir no-mkdir git no-git c/clean no-clean strict \
        v/verbose s/silent y/yes template= branch= remote= new-remote=? server= \
        check-existing name= \
        -- $argv
    or return 1

    if set -q _flag_help
        echo "$c_head""Usage:$c_reset $c_cmd""mkrep$c_reset $c_flag""[options]$c_reset $c_arg""<dir>$c_reset"
        echo
        echo "  Create $c_arg""<dir>$c_reset (with parents), cd into it, and git init it."
        echo
        echo "$c_head""Flags:$c_reset"
        echo "  $c_flag--cd$c_reset, $c_flag--no-cd$c_reset          Change into <dir> (default: --cd)"
        echo "  $c_flag--mkdir$c_reset, $c_flag--no-mkdir$c_reset    Create <dir> (default: --mkdir)"
        echo "  $c_flag--git$c_reset, $c_flag--no-git$c_reset        Run git init (default: --git)"
        echo "  $c_flag-c$c_reset, $c_flag--clean$c_reset            Remove <dir> first if it exists"
        echo "  $c_flag--no-clean$c_reset                Leave an existing <dir> alone (default)"
        echo "  $c_flag--strict$c_reset                Fail if <dir> already exists"
        echo "  $c_flag-v$c_reset, $c_flag--verbose$c_reset          Print each step as it runs"
        echo "  $c_flag-s$c_reset, $c_flag--silent$c_reset           Suppress all output (overrides -v)"
        echo "  $c_flag--template$c_reset $c_arg<path>$c_reset       git init --template=<path>"
        echo "  $c_flag--branch$c_reset $c_arg<name>$c_reset         git init -b <name>"
        echo "  $c_flag--remote$c_reset $c_arg<url>$c_reset          Link an existing remote"
        echo "  $c_flag--new-remote$c_reset $c_arg<cmd>$c_reset (optional)  Create + link a remote"
        echo "  $c_flag--server$c_reset $c_arg<type>$c_reset          Auto-create/link a remote (gitea, gitlab, github)"
        echo "  $c_flag--check-existing$c_reset          Report whether the repo exists; creates nothing"
        echo "  $c_flag-y$c_reset, $c_flag--yes$c_reset              Skip the \$GIT_SERVER remote-create confirmation"
        echo "  $c_flag--name$c_reset $c_arg<name>$c_reset           {name} substitution for --new-remote/--server"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset             Show this help message"
        echo
        echo "$c_head""Examples:$c_reset"
        echo "  $c_cmd""mkrep$c_reset $c_arg~/projects/my-new-repo$c_reset"
        echo "  $c_cmd""mkrep$c_reset $c_flag--clean --strict$c_reset $c_arg~/projects/scratch$c_reset"
        echo "  $c_cmd""mkrep$c_reset $c_flag--new-remote$c_reset $c_arg~/projects/foo$c_reset"
        return 0
    end

    if test (count $argv) -ne 1
        echo "$c_err""✘$c_reset  mkrep takes exactly one directory argument" >&2
        return 1
    end
    set -l dir $argv[1]

    if set -q _flag_remote; and set -q _flag_new_remote
        echo "$c_err""✘$c_reset  --remote and --new-remote are mutually exclusive" >&2
        return 1
    end
    if set -q _flag_server; and set -q _flag_remote
        echo "$c_err""✘$c_reset  --server and --remote are mutually exclusive" >&2
        return 1
    end
    if set -q _flag_server; and set -q _flag_new_remote
        echo "$c_err""✘$c_reset  --server and --new-remote are mutually exclusive" >&2
        return 1
    end
    if set -q _flag_check_existing; and set -q _flag_remote
        echo "$c_err""✘$c_reset  --check-existing and --remote are mutually exclusive" >&2
        return 1
    end
    if set -q _flag_check_existing; and set -q _flag_new_remote
        echo "$c_err""✘$c_reset  --check-existing and --new-remote are mutually exclusive" >&2
        return 1
    end
    if set -q _flag_no_git
        if set -q _flag_remote; or set -q _flag_new_remote; or set -q _flag_server
            echo "$c_err""✘$c_reset  --remote/--new-remote/--server require --git" >&2
            return 1
        end
    end

    set -l srv_type ''
    set -l srv_url ''
    # Track HOW the server was resolved, not just that it was. --server is an
    # explicit request to auto-create; an ambient $GIT_SERVER is not, and only
    # the latter needs confirming before we create a repo on a live forge.
    set -l srv_implicit 0
    if set -q _flag_server
        set srv_type $_flag_server
    else if test -n "$GIT_SERVER"
        set srv_type $GIT_SERVER
        set srv_implicit 1
    end
    if test -n "$srv_type"
        switch $srv_type
            case gitea
                if test -n "$GITEA_URL"
                    set srv_url $GITEA_URL
                else if test -n "$GITEA_HOST"
                    set srv_url "https://$GITEA_HOST"
                end
            case gitlab
                if test -n "$GITLAB_URL"
                    set srv_url $GITLAB_URL
                else if test -n "$GITLAB_HOST"
                    set srv_url "https://$GITLAB_HOST"
                end
            case github
                # gh defaults to github.com; no base url needed
            case '*'
                echo "$c_err""✘$c_reset  Unrecognized server type $c_arg$srv_type$c_reset (expected gitea, gitlab, or github)" >&2
                return 1
        end
    end

    if set -q _flag_check_existing; and test -z "$srv_type"
        echo "$c_err""✘$c_reset  --check-existing needs a resolved server (--server, \$GIT_SERVER, or \$GITEA_URL/\$GITEA_HOST/\$GITLAB_URL/\$GITLAB_HOST)" >&2
        return 1
    end

    set -l do_cd 1
    set -q _flag_no_cd; and set do_cd 0
    set -l do_mkdir 1
    set -q _flag_no_mkdir; and set do_mkdir 0
    set -l do_git 1
    set -q _flag_no_git; and set do_git 0
    set -l do_clean 0
    set -q _flag_clean; and set do_clean 1
    set -q _flag_no_clean; and set do_clean 0

    set -l verbose 0
    set -q _flag_verbose; and set verbose 1
    set -q _flag_silent; and set verbose 0
    set -l silent 0
    set -q _flag_silent; and set silent 1

    set -l orig_pwd $PWD

    if test $do_clean -eq 1; and test -d $dir
        _mkrep_verbose $silent $verbose "$c_dim""Removing existing $dir$c_reset"
        rm -rf -- $dir
        or begin
            echo "$c_err""✘$c_reset  Failed to remove existing $c_arg$dir$c_reset" >&2
            return 1
        end
        _mkrep_say $silent "$c_warn""⌫$c_reset  Removed existing $c_arg$dir$c_reset"
    end

    if set -q _flag_strict; and test -d $dir
        echo "$c_err""✘$c_reset  $c_arg$dir$c_reset already exists (--strict)" >&2
        return 1
    end

    set -l is_new 1
    test -d $dir; and set is_new 0

    if test $do_mkdir -eq 1
        if test $silent -eq 1
            _fish_mkdir_p --silent $dir
        else
            _fish_mkdir_p --tree $dir
        end
        or return 1
    else if not test -d $dir
        echo "$c_err""✘$c_reset  $c_arg$dir$c_reset does not exist and --no-mkdir was given" >&2
        return 1
    end

    if test $is_new -eq 1
        _mkrep_say $silent "$c_ok""✔$c_reset  Created $c_arg$dir$c_reset"
    else
        _mkrep_say $silent "$c_warn""→$c_reset  $c_arg$dir$c_reset already exists"
    end

    builtin cd $dir
    or begin
        echo "$c_err""✘$c_reset  Failed to enter $c_arg$dir$c_reset" >&2
        return 1
    end

    if test $do_git -eq 1
        set -l was_repo 0
        test -d .git; and set was_repo 1

        set -l git_init_args
        set -q _flag_template; and set -a git_init_args --template=$_flag_template
        set -q _flag_branch; and set -a git_init_args -b $_flag_branch

        _mkrep_verbose $silent $verbose "$c_dim""Running: git init $git_init_args$c_reset"
        if test $silent -eq 1
            git init $git_init_args >/dev/null 2>&1
        else
            git init $git_init_args >/dev/null
        end
        or begin
            echo "$c_err""✘$c_reset  git init failed in $c_arg$dir$c_reset" >&2
            builtin cd $orig_pwd
            return 1
        end

        if test $was_repo -eq 1
            _mkrep_say $silent "$c_warn""→$c_reset  $c_arg$dir$c_reset is already a git repository"
        else
            _mkrep_say $silent "$c_ok""✔$c_reset  Initialized git repository"
        end
    end

    if set -q _flag_remote
        _mkrep_verbose $silent $verbose "$c_dim""Running: git remote add origin $_flag_remote$c_reset"
        _mkrep_add_origin $silent $_flag_remote
        or begin
            builtin cd $orig_pwd
            return 1
        end
    end

    if set -q _flag_new_remote
        set -l cmd $_flag_new_remote
        test -z "$cmd"; and set cmd $MKREP_REMOTE_CMD
        if test -z "$cmd"
            echo "$c_err""✘$c_reset  --new-remote given no command and \$MKREP_REMOTE_CMD is unset" >&2
            builtin cd $orig_pwd
            return 1
        end

        set -l name $_flag_name
        test -z "$name"; and set name (path basename (path resolve $dir))
        set cmd (string replace -a '{name}' $name -- $cmd)
        set cmd (string replace -a '{user}' $USER -- $cmd)

        _mkrep_verbose $silent $verbose "$c_dim""Running: $cmd$c_reset"
        if test $silent -eq 1
            eval $cmd >/dev/null 2>&1
        else
            eval $cmd
        end
        or begin
            echo "$c_err""✘$c_reset  Remote-create command failed" >&2
            builtin cd $orig_pwd
            return 1
        end
        _mkrep_say $silent "$c_ok""✔$c_reset  Ran remote-create command"
    end

    if not set -q _flag_remote; and not set -q _flag_new_remote
        set -l name $_flag_name
        test -z "$name"; and set name (path basename (path resolve $dir))

        if set -q _flag_check_existing
            if _mkrep_repo_exists $srv_type $USER $name
                _mkrep_say $silent "$c_warn""→$c_reset  $c_arg$USER/$name$c_reset already exists on $srv_type"
            else
                _mkrep_say $silent "$c_ok""✔$c_reset  $c_arg$USER/$name$c_reset does not exist on $srv_type"
            end
        else if test -n "$srv_type"; and test $do_git -eq 1
            if _mkrep_repo_exists $srv_type $USER $name
                set -l url (_mkrep_remote_url $srv_type $USER $name $srv_url)
                _mkrep_say $silent "$c_warn""→$c_reset  $c_arg$USER/$name$c_reset already exists on $srv_type; linking instead of creating"
                _mkrep_add_origin $silent $url
                or begin
                    builtin cd $orig_pwd
                    return 1
                end
            else
                # Creating a repository on a live forge is the only outward-facing
                # thing mkrep does, and an exported $GIT_SERVER alone is enough to
                # reach here -- so a plain `mkrep foo`, which reads as purely
                # local, would silently make a repo on someone's server. Confirm
                # first. Skipped when the remote was asked for explicitly
                # (--server/--new-remote never reach this check) or with --yes.
                set -l do_create 1
                if test $srv_implicit -eq 1; and not set -q _flag_yes
                    set do_create 0
                    if status is-interactive; and isatty stdin
                        read -l -P (set_color yellow)"?"(set_color normal)"  Create new remote "(set_color --bold)"$USER/$name"(set_color normal)" on $srv_type? [y/N] " _reply
                        string match -qr '^[Yy]' -- "$_reply"; and set do_create 1
                    end
                    # Not gated on $silent: declining to do something the caller
                    # may be expecting is a diagnostic, and mkrep already writes
                    # its errors to stderr regardless of -s.
                    test $do_create -eq 0
                    and echo "$c_warn""→$c_reset  Skipped creating $c_arg$USER/$name$c_reset on $srv_type — pass $c_flag--yes$c_reset or $c_flag--server $srv_type$c_reset to create it" >&2
                end

                if test $do_create -eq 1
                    set -l cmd $MKREP_REMOTE_CMD
                    test -z "$cmd"; and set cmd (_mkrep_default_remote_cmd $srv_type)

                    if string match -q '*{server}*' -- $cmd
                        if test -z "$srv_url"
                            echo "$c_err""✘$c_reset  No base URL resolved for $srv_type (set \$GITEA_URL/\$GITEA_HOST or \$GITLAB_URL/\$GITLAB_HOST)" >&2
                            builtin cd $orig_pwd
                            return 1
                        end
                        set cmd (string replace -a '{server}' $srv_url -- $cmd)
                    end
                    set cmd (string replace -a '{name}' $name -- $cmd)
                    set cmd (string replace -a '{user}' $USER -- $cmd)

                    _mkrep_verbose $silent $verbose "$c_dim""Running: $cmd$c_reset"
                    if test $silent -eq 1
                        eval $cmd >/dev/null 2>&1
                    else
                        eval $cmd
                    end
                    or begin
                        echo "$c_err""✘$c_reset  Remote-create command failed" >&2
                        builtin cd $orig_pwd
                        return 1
                    end
                    set -l url (_mkrep_remote_url $srv_type $USER $name $srv_url)
                    _mkrep_say $silent "$c_ok""✔$c_reset  Created new remote $c_arg$url$c_reset on $srv_type"
                end
            end
        end
    end

    if test $do_cd -eq 0
        builtin cd $orig_pwd
    else
        _mkrep_say $silent "$c_ok""✔$c_reset  Entered $c_arg$dir$c_reset"
    end

    return 0
end
