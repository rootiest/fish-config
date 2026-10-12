# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  notify
# KIND      modifier
# PHASE     finally
# ORDER     80
# APPLIES   command fallback sequence dispatcher
# SUMMARY   Send a desktop notification when it finishes
# PHRASE    notifying you when it finishes ({notify_on})

#   ─────────────────────────────── Settings ───────────────────────────────

# When to notify. (choice: always fail success)
set -l notify_on always

# Notification title; empty uses the function name.
set -l notify_title

#   ─────────────────────────────── Fragment ───────────────────────────────

set -l __ft_title $notify_title
test -n "$__ft_title"; or set __ft_title (status current-function)
set -l __ft_outcome success
test $__ft_status -ne 0; and set __ft_outcome fail
if test "$notify_on" = always; or test "$notify_on" = $__ft_outcome
    set -l __ft_body "Finished successfully"
    test $__ft_outcome = fail; and set __ft_body "Failed with exit status $__ft_status"
    if command -q notify-send
        command notify-send -- "$__ft_title" "$__ft_body"
    else if test "$TERM" = xterm-kitty; or test "$TERM_PROGRAM" = WezTerm
        printf '\e]777;notify;%s;%s\e\\' "$__ft_title" "$__ft_body"
    end
end
