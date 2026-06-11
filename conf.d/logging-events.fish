# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# C5 — Logging & Capture: registers --on-variable event handlers at shell
# startup so that changes to __fish_config_op_logging or the master
# __fish_config_opinionated take effect immediately in every running shell.
# Also calls __fish_config_sync_logging once to reconcile sentinel-file and
# wrapper state with any variable values that were pre-set before this shell
# started.
#
# These functions must be defined in conf.d (not functions/) because fish
# only autoloads from functions/ on explicit call — event handlers that live
# solely in functions/ are never registered and their --on-variable triggers
# never fire.

function __fish_config_logging_changed --on-variable __fish_config_op_logging \
    --description 'C5 event handler: sync logging state when __fish_config_op_logging changes'
    __fish_config_sync_logging
end

function __fish_config_opinionated_changed --on-variable __fish_config_opinionated \
    --description 'C5 event handler: sync logging state when master opinionated switch changes'
    __fish_config_sync_logging
end

# Sync once at startup so pre-set variable values take effect without a re-set
__fish_config_sync_logging
