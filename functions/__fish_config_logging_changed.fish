# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_logging_changed
#
# DESCRIPTION
#   Event handler that fires in every running shell when
#   __fish_config_op_logging is set or erased. Delegates to
#   __fish_config_sync_logging to update the Kitty sentinel file and
#   paru/yay wrappers immediately without requiring a shell restart.
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   set -U __fish_config_op_logging 0  # triggers this automatically
function __fish_config_logging_changed --on-variable __fish_config_op_logging \
    --description 'C5 event handler: sync logging state when __fish_config_op_logging changes'
    __fish_config_sync_logging
end
