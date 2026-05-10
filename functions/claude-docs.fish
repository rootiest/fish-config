# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Update README.md with recent changes using Claude-code
function claude-docs --description 'Claude-code: Sync README with recent changes'
    claude "Analyze the recent changes and update the README.md to ensure all features, setup instructions, and examples are 100% accurate. Prune any obsolete information."
end
