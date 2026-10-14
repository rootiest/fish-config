# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __session_env_has_systemd
#
# DESCRIPTION
#   Succeeds when the system was booted with systemd, the only thing that
#   reads ~/.config/environment.d. A directory test, so no process is
#   forked; the first-run offer in conf.d/session-env-offer.fish uses it
#   to stay silent elsewhere.
#
# EXIT STATUS
#   0  Booted with systemd
#   1  Not
#
# EXAMPLE
#   __session_env_has_systemd; and echo "environment.d applies here"
function __session_env_has_systemd --description 'True when the system was booted with systemd'
    test -d /run/systemd/system
end
