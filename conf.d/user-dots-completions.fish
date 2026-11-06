# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#   ─────────────────────── User-dots completions/ ────────────────────────
# Completions specific to one machine live in the user-dots completions/
# directory. Prepending it makes them autoload on first Tab, exactly like
# ~/.config/fish/completions, and lets a file there replace this config's
# or the system's completion of the same name.
#
# Deliberately not behind an opinionated-component guard: the directory
# exists only if you created it, and gating it would silently drop your
# own completions. Cost: one test -d and one contains.
set -l __ud_completions (__fish_user_dots_dir)/completions
if test -d $__ud_completions; and not contains -- $__ud_completions $fish_complete_path
    set -g fish_complete_path $__ud_completions $fish_complete_path
end
