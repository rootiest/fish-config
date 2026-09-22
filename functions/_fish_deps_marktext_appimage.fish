# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm,mkdir), bypasses-shadow(mv), destructive, network
#
# SYNOPSIS
#   _fish_deps_marktext_appimage
#
# DESCRIPTION
#   Installs (or upgrades in place) MarkText as an AppImage at
#   ~/.local/bin/marktext. This is the install path for systems whose
#   package manager does not carry MarkText at all -- upstream ships only
#   the AUR package (marktext-bin) and its own GitHub release assets, so
#   apt/dnf/brew have nothing to offer.
#
#   The release assets embed their version in the filename, so there is no
#   stable /releases/latest/download URL; the download URL is read from the
#   GitHub API instead.
#
#   Upstream builds the Linux AppImage for x86_64 only.
#
# EXIT STATUS
#   0  MarkText installed at ~/.local/bin/marktext
#   1  Unsupported architecture, or the download or install failed
#
# EXAMPLE
#   _fish_deps_marktext_appimage
#
# NOTES
#   An AppImage needs FUSE to self-mount. Where FUSE is unavailable, run it
#   as `marktext --appimage-extract-and-run`.
function _fish_deps_marktext_appimage
    set -l arch (uname -m)
    if test "$arch" != x86_64
        echo "  MarkText publishes a Linux AppImage for x86_64 only (this is $arch)." >&2
        return 1
    end

    if not type -q curl
        echo "  curl is required to download the MarkText AppImage." >&2
        return 1
    end

    set -l url (curl -fsSL https://api.github.com/repos/marktext/marktext/releases/latest |
        string match -r '"browser_download_url":\s*"([^"]*-linux-[^"]*\.AppImage)"')[2]
    if test -z "$url"
        echo "  Could not find a Linux AppImage in the latest MarkText release." >&2
        return 1
    end

    set -l dest "$HOME/.local/bin/marktext"
    set -l tmp (mktemp -d)
    set -l ok 0
    curl -fL "$url" -o "$tmp/marktext"
    and mkdir -p (dirname $dest)
    and chmod +x "$tmp/marktext"
    # Replace via mv, not a write into $dest: overwriting a running AppImage
    # in place corrupts the live mount.
    and command mv -f "$tmp/marktext" "$dest"
    and set ok 1
    rm -rf $tmp

    if test $ok -eq 1
        fish_add_path "$HOME/.local/bin"
    end

    test $ok -eq 1
end
