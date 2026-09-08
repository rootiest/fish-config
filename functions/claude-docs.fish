# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# SYNOPSIS
#   claude-docs
#
# DESCRIPTION
#   Invokes Claude Code to analyze recent repository changes and update
#   README.md, ensuring all features and examples are accurate and pruning
#   obsolete content.
#
# EXIT STATUS
#   Exit status of the `claude` invocation
#
# EXAMPLE
#   claude-docs
function claude-docs --description 'Claude-code: Sync README with recent changes'
    __fish_help_header (status current-function) $argv; and return 0

    claude "Analyze the recent changes and update the README.md to ensure all features, setup instructions, and examples are 100% accurate. Prune any obsolete information."
end
