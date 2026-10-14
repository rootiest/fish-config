# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   network
#
# SYNOPSIS
#   _agents_repo_net_git <dir> <seconds> <git-args>...
#
# DESCRIPTION
#   Runs one git network operation (fetch, pull, ...) in <dir> so that it
#   can neither prompt nor hang: the operation can never ask for anything
#   and is killed after <seconds>.
#
#   Never asks. GIT_TERMINAL_PROMPT=0 closes git's own credential prompt,
#   GIT_ASKPASS and SSH_ASKPASS are pointed at a no-op so no askpass dialog
#   opens, and ssh is run with BatchMode=yes so it cannot ask for a
#   passphrase or a host-key decision (ssh opens the controlling terminal
#   for those even with stdin closed). None of it disturbs a configured
#   credential helper, which git consults before it ever prompts. The ssh
#   options are appended to the user's own ssh command (GIT_SSH_COMMAND,
#   else core.sshCommand) rather than replacing it, so a vault behind a
#   particular identity file or wrapper still authenticates.
#
#   Never hangs. The prompt controls close the prompt, not the socket: git
#   has no connect timeout for https at all (a blackholed address took 135s
#   to fail, measured), and http.lowSpeedLimit only counts once bytes are
#   moving. ssh gets ConnectTimeout=10, and the whole command runs under
#   timeout(1) for everything else. With no timeout(1) nothing is run at
#   all, since an unbounded network call is the one outcome this exists to
#   prevent; the status says so.
#
#   Stdin is /dev/null. Output is passed through; callers silence it.
#
# ARGUMENTS
#   dir       Repository to run in
#   seconds   Hard cap for the whole operation
#   git-args  Everything after `git -C <dir>`
#
# EXIT STATUS
#   0    The operation succeeded
#   4    timeout(1) is not installed; nothing was run
#   124  The cap expired (timeout(1)'s own status)
#   *    Otherwise git's exit status
#
# EXAMPLE
#   _agents_repo_net_git $agents_dir 20 pull --rebase --autostash -q
function _agents_repo_net_git
    set -l dir $argv[1]
    set -l secs $argv[2]
    set -l gitargs $argv[3..]
    test -n "$dir"; and test -n "$secs"; and test (count $gitargs) -gt 0; or return 2
    type -q timeout; or return 4

    set -l ssh_cmd $GIT_SSH_COMMAND
    test -n "$ssh_cmd"; or set ssh_cmd (command git -C "$dir" config core.sshCommand 2>/dev/null)
    test -n "$ssh_cmd"; or set ssh_cmd ssh

    command timeout $secs env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true \
        SSH_ASKPASS=true SSH_ASKPASS_REQUIRE=never \
        GIT_SSH_COMMAND="$ssh_cmd -o BatchMode=yes -o ConnectTimeout=10" \
        git -C "$dir" $gitargs </dev/null
end
