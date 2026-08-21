# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fzf_preview_media <file_path>
#
# DESCRIPTION
#   Preview helper for play-media. Looks for a thumbnail already generated
#   by a desktop file manager (Dolphin, Nautilus, GNOME Videos, ...) in the
#   freedesktop thumbnail cache and renders it via _fzf_preview_image if
#   found. Otherwise falls back to ffprobe-formatted metadata (duration,
#   codec, resolution, tags) when ffprobe is installed, or plain `file`
#   output as a last resort. Neither the thumbnail cache lookup nor ffprobe
#   are tracked in fish-deps: both are best-effort, matching how the
#   image-preview tool chain (kitten/chafa/viu/timg) is already handled.
#
# ARGUMENTS
#   file_path   Path to the audio/video file to preview
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   _fzf_preview_media ./Videos/clip.mp4
function _fzf_preview_media
    set -f file_path $argv
    if not test -e "$file_path"
        echo "$file_path doesn't exist." >&2
        return 0
    end

    set -l abs_path (realpath -- "$file_path" 2>/dev/null)

    # freedesktop.org thumbnail spec: md5 of the file:// URI names the
    # cached thumbnail. Dolphin/Nautilus/GNOME Videos already populate this
    # cache, so reuse it instead of generating a new thumbnail ourselves.
    set -l uri "file://"(string escape --style=url -- "$abs_path")
    set -l hash (echo -n "$uri" | md5sum | string split ' ')[1]
    set -l cache_home (set --query XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo "$HOME/.cache")

    for size in normal large x-large xx-large
        set -l thumb "$cache_home/thumbnails/$size/$hash.png"
        if test -f "$thumb"
            _fzf_preview_image "$thumb"
            return 0
        end
    end

    if command -q ffprobe
        set -l info (command ffprobe -v error -show_entries \
            format=duration,bit_rate:format_tags=title,artist,album:stream=codec_name,codec_type,width,height \
            -of default=noprint_wrappers=1 -- "$abs_path" 2>/dev/null)
        if test -n "$info"
            printf '%s\n' $info
            return 0
        end
    end

    command file --brief -- "$abs_path"
end
