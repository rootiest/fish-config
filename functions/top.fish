# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function top --wraps=btop --description 'Use btop as a modern replacement for top'
    # 1. Check if btop is actually installed
    if type -q btop
        # 2. Launch btop with any arguments passed
        btop $argv
    else
        # 3. Fallback to the original system top if btop is missing
        echo "btop not found, falling back to classic top..."
        command top $argv
    end
end
