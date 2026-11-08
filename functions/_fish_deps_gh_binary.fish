# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm,mkdir), bypasses-shadow(cp,mv), network
#
# SYNOPSIS
#   _fish_deps_gh_binary
#
# DESCRIPTION
#   Installs (or upgrades in place) gh, the GitHub command-line client, from
#   its latest release at ~/.local/bin/gh.
#
#   The latest version is read from the GitHub releases API (tag_name, with
#   its leading v dropped). The gh_VERSION_linux_ARCH.tar.gz asset is
#   verified against its line in the gh_VERSION_checksums.txt file published
#   with the same release before it is unpacked; a missing entry or a
#   mismatch aborts without touching the installed copy.
#
#   The archive is unpacked in a temporary directory and its bin/gh is staged
#   as a hidden file in ~/.local/bin, then renamed over ~/.local/bin/gh, so
#   the target is never a partial file.
#
#   Release builds are installed for x86_64 (amd64) and aarch64 (arm64)
#   only; any other machine is refused.
#
# EXIT STATUS
#   0  gh installed and verified
#   1  Unsupported architecture, curl or tar is missing, no version or digest
#      was found, or the download, verification, or install failed
#
# EXAMPLE
#   _fish_deps_gh_binary
function _fish_deps_gh_binary
    set -l arch (uname -m)
    switch $arch
        case x86_64
            set arch amd64
        case aarch64 arm64
            set arch arm64
        case '*'
            echo "  gh release builds are installed for x86_64 and aarch64 only (this is $arch)." >&2
            return 1
    end

    for tool in curl tar
        if not type -q $tool
            echo "  $tool is required to install gh from its release." >&2
            return 1
        end
    end

    set -l ver (curl -fsSL --proto '=https' https://api.github.com/repos/cli/cli/releases/latest \
        | string match -rg -- '"tag_name"\s*:\s*"v?([0-9][0-9A-Za-z.+-]*)"')[1]
    if test -z "$ver"
        echo "  Could not find the latest gh release." >&2
        return 1
    end

    set -l stem "gh_$ver"_linux_$arch
    set -l tgz "$stem.tar.gz"
    set -l base "https://github.com/cli/cli/releases/download/v$ver"
    set -l pattern '^([0-9a-fA-F]{64})\s+\*?'(string escape --style=regex -- $tgz)'$'
    set -l sum (curl -fsSL --proto '=https' "$base/gh_$ver"_checksums.txt | string match -rg -- $pattern)[1]
    if test -z "$sum"
        echo "  No published checksum found for $tgz; not installing." >&2
        return 1
    end

    set -l bindir "$HOME/.local/bin"
    set -l tmp (mktemp -d); or return 1
    set -l stage
    set -l ok 0
    _fish_deps_fetch_verified "$base/$tgz" "$tmp/$tgz" $sum
    and tar -xzf "$tmp/$tgz" -C "$tmp"
    and test -f "$tmp/$stem/bin/gh"
    and mkdir -p "$bindir"
    and set stage (mktemp "$bindir/.gh.XXXXXX")
    and command cp "$tmp/$stem/bin/gh" "$stage"
    and chmod 755 "$stage"
    and command mv -f "$stage" "$bindir/gh"
    and set ok 1
    rm -rf "$tmp"
    test -n "$stage"; and rm -f "$stage"
    if test $ok -ne 1
        echo "  gh was not installed." >&2
        return 1
    end
    return 0
end
