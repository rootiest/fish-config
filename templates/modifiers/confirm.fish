# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  confirm
# KIND      modifier
# PHASE     guard
# ORDER     40
# APPLIES   command fallback sequence dispatcher snippet per-host per-os jump
# SUMMARY   Ask before running, optionally only for matching arguments
# PHRASE    after asking for confirmation
# STATUS    1 if you answer no at the confirmation prompt

#   ─────────────────────────────── Settings ───────────────────────────────

# Question to ask before running.
set -l confirm_prompt 'Are you sure?'

# Only ask when your arguments match this regular expression; empty means always ask.
set -l confirm_only_if

#   ─────────────────────────────── Fragment ───────────────────────────────

# Ask unless the pattern clearly did not match: an empty pattern matches
# everything, and an invalid one (status 2) fails closed and still asks.
string match -qr -- "$confirm_only_if" "$argv"
if test $status -ne 1
    read -l -P "$confirm_prompt [y/N] " __ft_answer
    set -l __ft_answer_lc (string lower -- "$__ft_answer")
    if not contains -- "$__ft_answer_lc" y yes
        echo "Aborted." >&2
        return 1
    end
end
