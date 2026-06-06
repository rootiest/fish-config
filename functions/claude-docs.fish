# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   claude-docs
#
# DESCRIPTION
#   Invokes Claude Code to analyze recent repository changes and update
#   README.md, ensuring all features and examples are accurate and pruning
#   obsolete content.
#
# EXAMPLE
#   claude-docs
function claude-docs --description 'Claude-code: Sync README with recent changes'
    claude "Analyze the recent changes and update the README.md to ensure all features, setup instructions, and examples are 100% accurate. Prune any obsolete information."
end
