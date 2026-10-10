# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_release_tag DIR
#
# DESCRIPTION
#   Prints the newest release tag in the git repository at DIR: the highest
#   tag that is a plain X.Y.Z version number, compared as versions (4.10.0 is
#   newer than 4.9.3).
#
#   fish-shell tags its releases with bare version numbers (4.9.3). The
#   pre-releases (4.0b1) and the historical markers (LastC++03, official)
#   share the namespace, and are skipped.
#
# ARGUMENTS
#   DIR  A git working tree or bare repository that has its tags
#
# EXIT STATUS
#   0  A release tag was printed
#   1  No release tag exists (nothing is printed)
#
# RETURNS
#   The tag name on stdout
#
# EXAMPLE
#   set -l tag (_fish_deps_release_tag $clone); and git -C $clone checkout $tag
function _fish_deps_release_tag --argument-names dir
    set -l tag (git -C "$dir" tag --list --sort=version:refname 2>/dev/null \
        | string match -r '^\d+\.\d+\.\d+$' | tail -n 1)
    test -n "$tag"; or return 1
    echo $tag
end
