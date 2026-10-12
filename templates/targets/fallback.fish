# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  fallback
# KIND      target
# SUMMARY   Run the first of several commands that is installed
# PHRASE    Runs the first installed of {each:fallback_candidates}
# SYNOPSIS  {name} [ARGS...]
# STATUS    Exit status of the command that ran; 127 if none is installed
# EXAMPLE   {name} README.md

#   ─────────────────────────────── Settings ───────────────────────────────

# Commands to try, in order of preference. (list, required)
set -l fallback_candidates

#   ─────────────────────────── Fragment: guard ────────────────────────────

for __ft_candidate in $fallback_candidates
    if test "$__ft_candidate" = (status current-function)
        set cmd (command -s $__ft_candidate); or continue
    else
        type -q $__ft_candidate; or continue
        set cmd $__ft_candidate
    end
    break
end
if not set -q cmd[1]
    echo (status current-function)": none of these is installed: $fallback_candidates" >&2
    return 127
end

#   ──────────────────────────── Fragment: run ─────────────────────────────

$cmd $argv $__ft_append
set __ft_status $status
