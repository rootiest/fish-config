# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   _agents_repo_local_slug
#
# SYNOPSIS
#   _agents_repo_slug <dir>
#
# DESCRIPTION
#   Derives the vault slug for a project directory. Prefers the normalized
#   git remote URL so the same project keys identically from any clone on
#   any machine; falls back to a path-derived key when no remote exists.
#
#   Normalization strips the scheme, userinfo, and a numeric port, rewrites
#   scp-form host:path to host/path, drops a trailing .git, lowercases, and
#   maps every character outside [a-z0-9._-] to a dash. These all yield
#   git.rootiest.dev-rootiest-fish-config:
#
#     https://git.rootiest.dev/rootiest/fish-config.git
#     git@git.rootiest.dev:rootiest/fish-config.git
#     ssh://git@git.rootiest.dev:22/rootiest/fish-config.git
#
#   With no remote the slug is local-<sanitized-basename>-<8 hex of sha256(realpath)>,
#   where the basename is lowercased and mapped the same way as the remote form.
#   That key is machine-dependent by construction and is best-effort only;
#   agents-vault --adopt rebinds such an entry by hand.
#
# ARGUMENTS
#   dir  Absolute path to the project directory
#
# EXIT STATUS
#   0  Slug printed
#   1  No directory argument given
#
# RETURNS
#   The slug, one line on stdout.
#
# EXAMPLE
#   set -l slug (_agents_repo_slug /home/user/myproject)
function _agents_repo_slug --argument-names dir
    test -n "$dir"; or return 1

    set -l url (git -C "$dir" remote get-url origin 2>/dev/null)
    if test -z "$url"
        set -l remotes (git -C "$dir" remote 2>/dev/null)
        if test (count $remotes) -gt 0
            set url (git -C "$dir" remote get-url $remotes[1] 2>/dev/null)
        end
    end

    if test -n "$url"
        set -l s $url
        # Order matters: the port must go before the scp-form rewrite, or
        # ssh://host:22/a/b becomes host/22/a/b and diverges from the
        # https slug for the same repository.
        set s (string replace -r '^[A-Za-z][A-Za-z0-9+.-]*://' '' -- $s)
        set s (string replace -r '^[^@/]+@' '' -- $s)
        set s (string replace -r '^([^/:]+):[0-9]+/' '$1/' -- $s)
        set s (string replace -r '^([^/:]+):' '$1/' -- $s)
        set s (string replace -r '\.git$' '' -- $s)
        set s (string replace -r '/+$' '' -- $s)
        set s (string lower -- $s)
        set s (string replace -ra '[^a-z0-9._-]' '-' -- $s)
        printf '%s\n' $s
        return 0
    end

    _agents_repo_local_slug "$dir"
end
