# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for mkrep.
#
# The positional is the directory to create, so file completion stays on.
#
# --new-remote takes an OPTIONAL command, which argparse only accepts glued on
# (--new-remote=<cmd>); see #240 for the documented-but-unsupported space
# form. It is therefore declared without -r: fish will not swallow the next
# word as its value, so `mkrep --new-remote <Tab>` still completes the <dir>
# operand, which is what a bare --new-remote followed by a directory means.

complete -c mkrep -s h -l help -d 'Show help message'
complete -c mkrep -l cd -d 'Change into <dir> (default)'
complete -c mkrep -l no-cd -d 'Do not change into <dir>'
complete -c mkrep -l mkdir -d 'Create <dir> (default)'
complete -c mkrep -l no-mkdir -d 'Do not create <dir>'
complete -c mkrep -l git -d 'Run git init (default)'
complete -c mkrep -l no-git -d 'Do not run git init'
complete -c mkrep -s c -l clean -d 'Remove <dir> first if it already exists'
complete -c mkrep -l no-clean -d 'Leave an existing <dir> alone (default)'
complete -c mkrep -l strict -d 'Fail if <dir> already exists'
complete -c mkrep -s l -l local -d 'Force local only; ignore remote flags and env'
complete -c mkrep -s v -l verbose -d 'Print each step as it runs'
complete -c mkrep -s s -l silent -d 'Suppress all output (overrides --verbose)'
complete -c mkrep -s y -l yes -d 'Skip the $GIT_SERVER remote-create confirmation'
complete -c mkrep -l template -r -F -d 'git init --template=<path>'
complete -c mkrep -l branch -x -a 'main master trunk develop' -d 'Initial branch name (git init -b)'
complete -c mkrep -l remote -x -d 'Link an existing remote URL'
complete -c mkrep -l new-remote -d 'Create and link a remote (--new-remote=<cmd>, or $MKREP_REMOTE_CMD)'
complete -c mkrep -l server -x -a 'gitea\t"Gitea instance" gitlab\t"GitLab instance" github\t"GitHub"' -d 'Auto-create or link a remote on this forge'
complete -c mkrep -l check-existing -d 'Report whether the repo exists on the server'
complete -c mkrep -l name -x -d 'Repository name for {name} (default: <dir> basename)'
