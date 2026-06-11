# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_opinionated_changed
#
# DESCRIPTION
#   Event handler that fires in every running shell when
#   __fish_config_opinionated (the master opinionated switch) is set or
#   erased. Delegates to __fish_config_sync_logging to keep C5 logging
#   state in sync. Logging is the only category with external on-disk
#   state (sentinel file, wrapper scripts) that requires real-time
#   synchronisation when the master variable changes; C1-C4 guards
#   evaluate at call-time and need no event handler.
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   set -U __fish_config_opinionated 0  # triggers this automatically
function __fish_config_opinionated_changed --on-variable __fish_config_opinionated \
    --description 'C5 event handler: sync logging state when master opinionated switch changes'
    __fish_config_sync_logging
end
