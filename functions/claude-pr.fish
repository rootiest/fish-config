# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Create a new git branch, commit, push, and PR using Claude-code
function claude-pr --description 'Claude-code: New branch, commit, push, and PR'
    claude "Act as a senior engineer. Execute this sequence: 1. Create a new git branch (kebab-case). 2. Stage changes and write a Conventional Commit message. 3. Self-verify the changes by running relevant build/test commands or linting. 4. Push to remote. 5. Create a PR to 'main' including a summary of changes and a 'Manual Verification' section containing a Markdown checklist (- [ ]) of specific, bite-sized steps required to manually verify the functionality."
end
