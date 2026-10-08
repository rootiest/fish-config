# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm,mkdir), bypasses-shadow(cp), network
#
# SYNOPSIS
#   _fish_deps_win32yank_binary
#
# DESCRIPTION
#   Installs win32yank (the WSL2 clipboard bridge) at
#   ~/.local/bin/win32yank.exe.
#
#   Upstream publishes no checksum file, so the release is pinned: the
#   version and its SHA-256 digest are recorded below (the digest matches
#   the one in Scoop's win32yank manifest). Bump both together when a new
#   upstream release ships.
#
# EXIT STATUS
#   0  win32yank installed and verified
#   1  The download, verification, or install failed
#
# EXAMPLE
#   _fish_deps_win32yank_binary
function _fish_deps_win32yank_binary
    set -l ver 0.1.1
    set -l sha256 247c9a05b94387a884b49d3db13f806b1677dfc38020f955f719be6902260cd6
    set -l zip win32yank-x64.zip

    set -l tmp (mktemp -d)
    set -l ok 0
    _fish_deps_fetch_verified "https://github.com/equalsraf/win32yank/releases/download/v$ver/$zip" "$tmp/$zip" $sha256
    and unzip -o -q "$tmp/$zip" -d "$tmp"
    and mkdir -p "$HOME/.local/bin"
    and command cp "$tmp/win32yank.exe" "$HOME/.local/bin/win32yank.exe"
    and chmod +x "$HOME/.local/bin/win32yank.exe"
    and set ok 1
    rm -rf "$tmp"
    test $ok -eq 1
end
