# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   13-media-and-utilities
#
# SYNOPSIS
#   play-media [-p|--player <cmd>]
#   play-media --help
#
# DESCRIPTION
#   Opens an fzf picker (with thumbnail/metadata preview via
#   _fzf_preview_media) listing audio and video files under the current
#   directory, and plays the selection(s) in the best available media
#   player. Supports multi-select (Tab) to queue several files at once.
#
#   Player resolution order:
#     1. -p/--player <cmd>   (explicit override, validated as a command)
#     2. $play_media_player  (explicit override, validated as a command)
#     3. xdg-mime default handler for the first selected file's mimetype
#     4. First known player binary found in a built-in list (mpv, vlc)
#
#   The player is launched backgrounded and detached, mirroring open-url,
#   so the shell is never blocked.
#
# ARGUMENTS
#   -p, --player <cmd>   Force a specific player command
#   -h, --help           Print usage and exit
#
# EXIT STATUS
#   0  Player launched (or the picker was cancelled)
#   1  No media files found, invalid --player/$play_media_player, or no
#      player found
#
# EXAMPLE
#   play-media
#   play-media --player mpv
function play-media --description 'Pick audio/video files with fzf and play them'
    argparse h/help p/player= -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: play-media [-p|--player <cmd>]"
        echo "Pick audio/video files under the current directory with fzf and play them."
        echo
        echo "  -p, --player <cmd>  Force a specific player command"
        echo "  -h, --help          Show this help"
        return 0
    end

    set -l audio_exts mp3 flac wav ogg oga opus m4a aac wma alac aiff
    set -l video_exts mp4 mkv webm avi mov wmv flv m4v mpg mpeg ts

    # Directly use fd binary to avoid output buffering delay caused by a fd
    # alias, if any. Debian-based distros install fd as fdfind.
    set -f fd_cmd (command -v fdfind || command -v fd || echo "fd")
    set -f --append fd_cmd --color=always $fzf_fd_opts
    for ext in $audio_exts $video_exts
        set -f --append fd_cmd -e $ext
    end

    set -l selection ($fd_cmd 2>/dev/null | _fzf_wrapper --ansi --multi \
        --height=90% \
        --layout=reverse \
        --border=rounded \
        --border-label=' Play Media ' \
        --prompt='Play> ' \
        --header='Enter: Play  Tab: Select  Ctrl-/: Toggle Preview  Esc: Cancel' \
        --bind='ctrl-/:toggle-preview' \
        --preview='_fzf_preview_media {}' \
        --preview-window='right:50%:wrap:border-left')

    if test -z "$selection"
        return 0
    end

    set -l player
    if set -q _flag_player
        set player $_flag_player
        if not type -q $player[1]
            set_color red
            echo "error: --player '$player[1]' is not a valid command" >&2
            set_color normal
            return 1
        end
    else if set -q play_media_player
        echo $play_media_player | read -at player
        if not type -q $player[1]
            set_color red
            echo "error: \$play_media_player '$player[1]' is not a valid command" >&2
            set_color normal
            return 1
        end
    else
        if type -q xdg-mime; and command -q file
            set -l mime (command file --brief --mime-type -- "$selection[1]" 2>/dev/null)
            set -l desk (xdg-mime query default "$mime" 2>/dev/null)
            if test -n "$desk"
                set -l candidate (string replace -r '\.desktop$' '' -- $desk)
                if type -q $candidate
                    set player $candidate
                end
            end
        end

        if not set -q player[1]
            for p in mpv vlc
                if type -q -f $p
                    set player $p
                    break
                end
            end
        end
    end

    if not set -q player[1]
        set_color red
        echo "error: could not find a media player — set \$play_media_player, pass --player, or install mpv/vlc" >&2
        set_color normal
        return 1
    end

    # Background the player so it doesn't block the terminal, and discard
    # its own console chatter, mirroring open-url.
    sh -c '("$@") >/dev/null 2>&1 &' -- $player $selection
    return 0
end
