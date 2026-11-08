# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm,mkdir), bypasses-shadow(mv), network
#
# SYNOPSIS
#   _fish_deps_tea_binary
#
# DESCRIPTION
#   Installs (or upgrades in place) tea, the Gitea command-line client, from
#   its latest release at ~/.local/bin/tea.
#
#   The latest version is read from the gitea.com releases API (tag_name,
#   with its leading v dropped). The binary comes from dl.gitea.com and is
#   verified against the .sha256 file published next to it before it is
#   made executable; a missing digest or a mismatch aborts without touching
#   the installed copy.
#
#   The download is staged as a hidden file in ~/.local/bin and renamed over
#   ~/.local/bin/tea only once it is verified and executable, so the target
#   is never a partial file, and a running tea keeps its old inode.
#
#   Release builds are installed for x86_64 (amd64) and aarch64 (arm64)
#   only; any other machine is refused.
#
# EXIT STATUS
#   0  tea installed and verified
#   1  Unsupported architecture, curl is missing, no version or digest was
#      found, or the download, verification, or install failed
#
# EXAMPLE
#   _fish_deps_tea_binary
function _fish_deps_tea_binary
    set -l arch (uname -m)
    switch $arch
        case x86_64
            set arch amd64
        case aarch64 arm64
            set arch arm64
        case '*'
            echo "  tea release builds are installed for x86_64 and aarch64 only (this is $arch)." >&2
            return 1
    end

    if not type -q curl
        echo "  curl is required to download tea." >&2
        return 1
    end

    set -l ver (curl -fsSL --proto '=https' https://gitea.com/api/v1/repos/gitea/tea/releases/latest \
        | string match -rg -- '"tag_name"\s*:\s*"v?([0-9][0-9A-Za-z.+-]*)"')[1]
    if test -z "$ver"
        echo "  Could not find the latest tea release." >&2
        return 1
    end

    set -l name "tea-$ver-linux-$arch"
    set -l url "https://dl.gitea.com/tea/$ver/$name"
    set -l pattern '^([0-9a-fA-F]{64})\s+\*?'(string escape --style=regex -- $name)'$'
    set -l sum (curl -fsSL --proto '=https' "$url.sha256" | string match -rg -- $pattern)[1]
    if test -z "$sum"
        echo "  No published checksum found for $name; not installing." >&2
        return 1
    end

    set -l bindir "$HOME/.local/bin"
    mkdir -p "$bindir"; or return 1
    set -l stage (mktemp "$bindir/.tea.XXXXXX"); or return 1
    set -l ok 0
    _fish_deps_fetch_verified "$url" "$stage" $sum
    and chmod 755 "$stage"
    and command mv -f "$stage" "$bindir/tea"
    and set ok 1
    rm -f "$stage"
    test $ok -eq 1
end
