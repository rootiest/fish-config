# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Defines fish_prompt only when starship is installed.
# Without starship, fish's built-in prompt already emits OSC 133;A
# on the prompt line itself, so no wrapper is needed.

# Replacing the prompt is opinionated (C3 overrides)
__fish_config_op_enabled __fish_config_op_overrides; or return

type -q starship; or return

function fish_prompt
    set -l last_status $status

    # Blank line between output and next prompt, skipped at the top of a cleared screen
    if not test "$fish_private_mode" = true; and test (commandline) = ""
        echo
    end

    # OSC 133;A here (after the blank line) puts the marker on the prompt line itself,
    # not the blank line — required for ov's section-delimiter to pin the right line.
    printf "\x1b]133;A\x07"

    set -g STARSHIP_CMD_STATUS $last_status
    command starship prompt --status=$last_status --pipestatus=$pipestatus --jobs=(count (jobs -p))

    printf "\x1b]133;B\x07"
end
