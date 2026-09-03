# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_repo_local_slug <dir>
#
# DESCRIPTION
#   Builds the path-derived fallback slug used when a project has no git
#   remote: local-<sanitized-basename>-<8 hex of sha256(realpath)>. The
#   basename is lowercased and every character outside [a-z0-9._-] is
#   mapped to a dash, matching the sanitization the remote-URL branch of
#   _agents_repo_slug applies to hostnames and paths.
#
#   This is the single source of truth for that formula. It exists so the
#   rule is written once: _agents_repo_slug's no-remote branch calls it to
#   produce the slug, and agents-vault's slug-migration fallback (used when
#   there is no live symlink yet to read the previous slug from) calls it
#   to recompute the same candidate. Duplicating the formula in both places
#   let them drift once before; this closes that gap for good.
#
# ARGUMENTS
#   dir  Absolute or relative path to the project directory
#
# EXIT STATUS
#   0  Slug printed
#   1  No directory argument given
#
# RETURNS
#   The local-* slug, one line on stdout.
#
# EXAMPLE
#   set -l slug (_agents_repo_local_slug /home/user/myproject)
function _agents_repo_local_slug --argument-names dir
    test -n "$dir"; or return 1

    set -l rp (path resolve "$dir")
    set -l base (string lower -- (path basename "$rp") | string replace -ra '[^a-z0-9._-]' '-')
    set -l digest (printf '%s' "$rp" | sha256sum | string split -f1 ' ')
    printf 'local-%s-%s\n' "$base" (string sub -l 8 -- "$digest")
end
