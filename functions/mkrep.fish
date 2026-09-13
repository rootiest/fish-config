# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# DEPENDENCIES
#   _fish_mkdir_p, __fish_palette, _mkrep_say, _mkrep_verbose, git
#
# SYNOPSIS
#   mkrep [--cd | --no-cd] [--mkdir | --no-mkdir] [--git | --no-git]
#         [-c | --clean | --no-clean] [--strict] [-v | --verbose]
#         [-s | --silent] [--template <path>] [--branch <name>]
#         [--remote <url>] [--new-remote [<cmd>]] [--name <name>]
#         [-h | --help] <dir>
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
#   <url>) -- it does not create anything. --new-remote creates one first
#   by running a shell command template in the new repo directory, then
#   nothing further is needed since the template itself does the linking
#   (e.g. gh repo create {name} --source=. --remote=origin --push).
#   Two placeholders are substituted in the template: {name} (--name, or
#   the target directory's basename) and {user} ($USER). Pass a command
#   after --new-remote to use it for this call only; with no value it
#   falls back to $MKREP_REMOTE_CMD. --remote and --new-remote are
#   mutually exclusive, and either requires --git.
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
#   --name <name>    {name} substitution when --new-remote (default: <dir>'s
#                    basename)
#   -h, --help       Show this help message
#
# EXIT STATUS
#   0  All requested steps completed
#   1  Bad arguments, or a step (mkdir, cd, git init, remote) failed
#
# EXAMPLE
#   mkrep ~/projects/my-new-repo
#   mkrep --clean --strict ~/projects/scratch
#   mkrep --remote git@git.example.com:me/foo.git ~/projects/foo
#   set -Ux MKREP_REMOTE_CMD 'gh repo create {name} --private --source=. --remote=origin --push'
#   mkrep --new-remote ~/projects/foo
#
#   Starting points for $MKREP_REMOTE_CMD, one per host CLI -- each assumes
#   that tool is already installed and authenticated, creates a private
#   repo under the caller's own account, and pushes the initial commit.
#   gh and glab support a one-shot --source/--remote/--push; tea's create
#   does not, so it is chained with the git commands that do the linking
#   (adjust the host in the URL to your Gitea instance):
#     GitHub (gh):   gh repo create {name} --private --source=. --remote=origin --push
#     GitLab (glab): glab repo create {name} --private --source=. --remote=origin --push
#     Gitea (tea):   tea repo create --name {name} --private && git remote add origin https://YOUR-GITEA-HOST/{user}/{name}.git && git push -u origin HEAD
function mkrep --description 'Create a directory, cd into it, and git init it'
    __fish_palette

    argparse h/help cd no-cd mkdir no-mkdir git no-git c/clean no-clean strict \
        v/verbose s/silent template= branch= remote= new-remote=? name= \
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
        echo "  $c_flag--name$c_reset $c_arg<name>$c_reset           {name} substitution for --new-remote"
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
    if set -q _flag_no_git
        if set -q _flag_remote; or set -q _flag_new_remote
            echo "$c_err""✘$c_reset  --remote/--new-remote require --git" >&2
            return 1
        end
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

    cd $dir
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
            cd $orig_pwd
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
        git remote add origin $_flag_remote
        or begin
            echo "$c_err""✘$c_reset  Failed to add remote $c_arg$_flag_remote$c_reset" >&2
            cd $orig_pwd
            return 1
        end
        _mkrep_say $silent "$c_ok""✔$c_reset  Linked remote $c_arg$_flag_remote$c_reset"
    end

    if set -q _flag_new_remote
        set -l cmd $_flag_new_remote
        test -z "$cmd"; and set cmd $MKREP_REMOTE_CMD
        if test -z "$cmd"
            echo "$c_err""✘$c_reset  --new-remote given no command and \$MKREP_REMOTE_CMD is unset" >&2
            cd $orig_pwd
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
            cd $orig_pwd
            return 1
        end
        _mkrep_say $silent "$c_ok""✔$c_reset  Ran remote-create command"
    end

    if test $do_cd -eq 0
        cd $orig_pwd
    else
        _mkrep_say $silent "$c_ok""✔$c_reset  Entered $c_arg$dir$c_reset"
    end

    return 0
end
