# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm), network
#
# SYNOPSIS
#   _fish_deps_fetch_verified URL DEST SHA256
#
# DESCRIPTION
#   Downloads URL to DEST and checks the file against the expected SHA-256
#   digest before anything else touches it. On any failure (HTTP error,
#   truncated transfer, digest mismatch, no hashing tool) DEST is removed,
#   so a caller chaining `and chmod +x` never sees an unverified file.
#
#   Uses sha256sum, falling back to `shasum -a 256`. With neither present
#   the download is refused rather than trusted.
#
# ARGUMENTS
#   URL     HTTPS URL to download
#   DEST    File to write
#   SHA256  Expected digest, 64 hex characters (case-insensitive)
#
# EXIT STATUS
#   0  DEST exists and matches SHA256
#   1  Download failed, digest mismatched, or no SHA-256 tool is available
#   2  Usage error
#
# EXAMPLE
#   _fish_deps_fetch_verified https://example.com/tool.zip /tmp/tool.zip 247c9a05…
function _fish_deps_fetch_verified --argument-names url dest want
    if test (count $argv) -ne 3
        echo "  usage: _fish_deps_fetch_verified URL DEST SHA256" >&2
        return 2
    end
    set want (string lower -- $want)
    if not string match -qr '^[0-9a-f]{64}$' -- $want
        echo "  No valid SHA-256 digest to verify $url against; refusing to download." >&2
        return 1
    end

    set -l hasher
    if type -q sha256sum
        set hasher sha256sum
    else if type -q shasum
        set hasher shasum -a 256
    else
        echo "  sha256sum or shasum is required to verify downloads." >&2
        return 1
    end

    if not curl -fsSL --proto '=https' -o "$dest" "$url"
        echo "  Download failed: $url" >&2
        rm -f "$dest"
        return 1
    end

    set -l got (command $hasher "$dest" | string split -f1 ' ')
    if test "$got" != "$want"
        echo "  Checksum mismatch for $url" >&2
        echo "    expected $want" >&2
        echo "    got      $got" >&2
        rm -f "$dest"
        return 1
    end
end
