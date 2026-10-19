# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _git_sweep_host <url-or-host>
#
# DESCRIPTION
#   Prints the bare, lowercased host of a git remote URL, a web URL, or a
#   host value from an environment variable: the scheme, user, port and
#   path are dropped. Handles https://host/..., ssh://user@host:port/...,
#   scp-style user@host:path, and a bare host.
#
# EXIT STATUS
#   0  A host was found
#   1  The input holds no host (e.g. a local path remote)
#
# RETURNS
#   The host, e.g. git.rootiest.dev
#
# EXAMPLE
#   _git_sweep_host git@git.rootiest.dev:rootiest/fish-config.git
function _git_sweep_host --argument-names url
    # A local path or file:// remote has no host.
    string match -qr '^(/|\.|~|file://)' -- $url; and return 1
    set -l h (string replace -r '^[a-zA-Z][a-zA-Z0-9+.-]*://' '' -- $url)
    set h (string replace -r '/.*' '' -- $h)
    set h (string replace -r '^.*@' '' -- $h)
    set h (string replace -r ':.*' '' -- $h)
    test -n "$h"; or return 1
    # string lower fails when nothing changed, so don't return its status.
    string lower -- $h
    return 0
end
