# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for search.
#
# search hands its arguments to paru (or yay), whose bare-argument mode is an
# interactive search-and-install. Search terms are usually package names, so
# offer the repo packages, plus the helper's own options.

if type -q paru
    complete -c search -w paru
else if type -q yay
    complete -c search -w yay
end

complete -c search -f -a '(__fish_print_pacman_packages)'
