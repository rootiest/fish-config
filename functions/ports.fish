# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function ports -d "Show active network listeners"
    sudo lsof -iTCP -sTCP:LISTEN -P -n
end
