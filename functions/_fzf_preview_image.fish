# helper function for _fzf_preview_file
function _fzf_preview_image --description "Render an image preview using the best available tool for the current terminal."
    set -f file_path $argv

    set -l cols (set --query FZF_PREVIEW_COLUMNS; and echo $FZF_PREVIEW_COLUMNS; or echo 80)
    set -l lines (set --query FZF_PREVIEW_LINES; and echo $FZF_PREVIEW_LINES; or echo 24)
    set -l left (set --query FZF_PREVIEW_LEFT; and echo $FZF_PREVIEW_LEFT; or echo 0)
    set -l top (set --query FZF_PREVIEW_TOP; and echo $FZF_PREVIEW_TOP; or echo 0)

    # Terminals that implement the kitty graphics protocol (kitty itself,
    # WezTerm, and Ghostty) can render via `kitten icat` even when it's not
    # the active terminal, since `kitten` is just an escape-sequence emitter.
    set -l kitty_capable 0
    if set --query KITTY_WINDOW_ID
        or test "$TERM" = xterm-kitty
        or contains -- "$TERM_PROGRAM" WezTerm ghostty
        or set --query GHOSTTY_RESOURCES_DIR
        set kitty_capable 1
    end

    if test $kitty_capable -eq 1; and command -q kitten
        # --place is measured from the top-left of the whole terminal, not the
        # preview pane, so FZF_PREVIEW_LEFT/TOP (added to fzf specifically for
        # this integration) are required to land the image in the right spot.
        command kitten icat --clear --transfer-mode=memory --unicode-placeholder \
            --stdin=no --place="$cols"x"$lines"@"$left"x"$top" -- "$file_path" 2>/dev/null
    else if command -q chafa
        command chafa --size="$cols"x"$lines" -- "$file_path"
    else if command -q viu
        command viu --width $cols -- "$file_path"
    else if command -q timg
        command timg -g "$cols"x"$lines" -- "$file_path"
    else
        set_color yellow
        echo "No image preview tool available (install kitty, chafa, viu, or timg)."
        set_color normal
        command file --brief -- "$file_path"
    end
end
