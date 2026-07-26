# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __kitty_logging_has_watcher
#
# DESCRIPTION
#   Succeeds (returns 0) when the top-level kitty.conf contains an active
#   (non-commented) `watcher` directive — whether the fish-config managed one or
#   a user's own. Used to suppress the setup reminder and to inform status.
#
# EXIT STATUS
#   0  An active watcher directive is present
#   1  None present, or kitty.conf does not exist
#
# EXAMPLE
#   __kitty_logging_has_watcher; and echo "already wired"
function __kitty_logging_has_watcher --description 'True if kitty.conf has an active watcher directive'
    set -l conf (__kitty_logging_dir)/kitty.conf
    test -f $conf; or return 1
    command grep -qE '^[[:space:]]*watcher[[:space:]]' $conf
end
