# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#   ──────────────────────── User-dots functions/ ─────────────────────────
# Functions you generate with fish-template, or write yourself, live in the
# user-dots functions/ directory. Prepending it makes them autoload and lets
# them override this config's functions of the same name.
#
# Deliberately not behind an opinionated-component guard: the directory
# exists only if you created it, and gating it would silently unload your
# own functions. Cost: one test -d and one contains.
set -l __ud_functions (__fish_user_dots_dir)/functions
if test -d $__ud_functions; and not contains -- $__ud_functions $fish_function_path
    set -g fish_function_path $__ud_functions $fish_function_path
end
