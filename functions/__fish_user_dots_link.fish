# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_user_dots_link
#
# DESCRIPTION
#   Manages the git-ignored `user-dots` convenience symlink in the fish config
#   directory ($__fish_config_dir/user-dots), pointing it at the resolved
#   $__fish_user_dots_path so the private overlay can be browsed from
#   ~/.config/fish/.
#
#   Behaviour is controlled by the __fish_user_dots_symlink toggle:
#     - explicit falsy (0/false/…) — remove our symlink if present and stop.
#       Honoured regardless of C2, so opting out always cleans up.
#     - unset or truthy (default)   — create the link if missing and repoint it
#       if the target changed. This is a C2 startup side-effect, so it only
#       creates when __fish_config_op_autoexec is enabled.
#
#   Only ever manages a symlink; a real file or directory at that path is left
#   untouched.
#
# ARGUMENTS
#   (none)
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   __fish_user_dots_link
function __fish_user_dots_link --description 'Manage the user-dots convenience symlink'
    set -l link "$__fish_config_dir/user-dots"
    set -q __fish_user_dots_path
        or set -l __fish_user_dots_path "$XDG_CONFIG_HOME/.user-dots/fish"

    # Explicit opt-out: remove our symlink (never a real file/dir) and stop.
    __fish_variable_check __fish_user_dots_symlink
    if test $status -eq 1
        test -L "$link"; and rm -f "$link"
        return 0
    end

    # Enabled: creation is a C2 startup side-effect.
    __fish_config_op_enabled __fish_config_op_autoexec; or return 0

    test -d "$__fish_user_dots_path"; or return 0
    if test -L "$link"
        test (readlink "$link") != "$__fish_user_dots_path"
            and ln -sfn "$__fish_user_dots_path" "$link"
    else if not test -e "$link"
        ln -s "$__fish_user_dots_path" "$link"
    end
end
