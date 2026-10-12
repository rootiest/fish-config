# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  sequence
# KIND      target
# SUMMARY   Run several command lines, one after another
# PHRASE    Runs these steps in order: {each:sequence_steps}
# SYNOPSIS  {name}
# STATUS    0 if every step succeeded, else the status of the failing step
# EXAMPLE   {name}

#   ─────────────────────────────── Settings ───────────────────────────────

# Command lines to run, in order; each can be any command, including your own functions. (lines, required)
set -l sequence_steps

# What to do when a step fails. (choice: stop continue)
set -l sequence_on_fail stop

#   ──────────────────────────── Fragment: run ─────────────────────────────

set __ft_status 0
for __ft_step in $sequence_steps
    eval $__ft_step
    set -l __ft_rc $status
    if test $__ft_rc -ne 0
        set __ft_status $__ft_rc
        test "$sequence_on_fail" = stop; and break
    end
end
