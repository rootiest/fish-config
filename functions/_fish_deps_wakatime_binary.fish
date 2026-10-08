# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm,mkdir), bypasses-shadow(cp), network
#
# SYNOPSIS
#   _fish_deps_wakatime_binary
#
# DESCRIPTION
#   Installs (or upgrades in place) wakatime-cli from its latest GitHub
#   release at ~/.config/wakatime/wakatime, symlinked into ~/.local/bin.
#
#   The release zip is verified against the checksums_sha256.txt file
#   published with the same release before it is unpacked; a missing entry
#   or a mismatch aborts without touching the installed binary.
#
# EXIT STATUS
#   0  wakatime-cli installed and verified
#   1  The download, verification, or install failed
#
# EXAMPLE
#   _fish_deps_wakatime_binary
function _fish_deps_wakatime_binary
    set -l arch (uname -m)
    switch $arch
        case x86_64
            set arch amd64
        case aarch64 arm64
            set arch arm64
        case armv7l
            set arch arm
        case '*'
            set arch amd64
    end
    set -l base https://github.com/wakatime/wakatime-cli/releases/latest/download
    set -l zip "wakatime-cli-linux-$arch.zip"
    set -l wt_dir "$HOME/.config/wakatime"
    set -l wt_bin "$wt_dir/wakatime"

    set -l pattern '^([0-9a-fA-F]{64})\s+\*?'(string escape --style=regex -- $zip)'$'
    set -l sum (curl -fsSL --proto '=https' "$base/checksums_sha256.txt" | string match -r -- $pattern)[2]
    if test -z "$sum"
        echo "  No published checksum found for $zip; not installing." >&2
        return 1
    end

    set -l tmp (mktemp -d)
    set -l ok 0
    _fish_deps_fetch_verified "$base/$zip" "$tmp/$zip" $sum
    and unzip -o -q "$tmp/$zip" -d "$tmp"
    and mkdir -p "$wt_dir" "$HOME/.local/bin"
    and command cp "$tmp/wakatime-cli-linux-$arch" "$wt_bin"
    and chmod +x "$wt_bin"
    and ln -sf "$wt_bin" "$HOME/.local/bin/wakatime"
    and set ok 1
    rm -rf "$tmp"
    test $ok -eq 1
end
