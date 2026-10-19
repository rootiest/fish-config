# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Keeps docs/command-shadows.json (the agent-readable list of shadowed
# commands) in step with the opinionated toggles. Checking before every
# prompt catches a toggle changed from any shell or from config-settings;
# the check is a fingerprint compare, and only a stale file costs a
# background write.
#
# The handler must be defined in conf.d: fish only autoloads functions/ on
# an explicit call, so an event handler there would never be registered.
status is-interactive; or return

function __fish_config_shadows_refresh --on-event fish_prompt \
    --description 'Regenerate docs/command-shadows.json when its toggles or catalog change'
    __fish_config_shadows_write --if-stale --background
end
