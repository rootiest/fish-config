# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function claude --wraps='claude --remote-control' --description 'claude with --remote-control always enabled'
    if contains -- --remote-control $argv
        command claude $argv
    else
        command claude --remote-control $argv
    end
end
