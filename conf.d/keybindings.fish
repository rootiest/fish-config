# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

if not status is-interactive
    exit
end

# Ctrl+Alt+U — strip the first command token and place cursor at start to retype it
for mode in default insert
    bind --mode $mode ctrl-alt-u _replace_command_token
end
