# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_init_stub
#
# DESCRIPTION
#   Prints the AGENTS.md that agents-init writes for a project with no
#   agent instructions of its own: a heading and a directive telling
#   agents to edit AGENTS/AGENTS.md rather than the root symlink.
#
#   One source for the text: _agents_init_sync_instructions writes it, and
#   agents-cleanup compares against it byte for byte to recognize a stub
#   that never held user content.
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The stub, on stdout.
#
# EXAMPLE
#   _agents_init_stub >AGENTS/AGENTS.md
function _agents_init_stub
    printf '%s\n' \
        '# AGENTS.md' \
        '' \
        '> ⚠️ **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' \
        '> You may be reading this file via a symlink (`AGENTS.md`) in' \
        '> the root of the project. Your environment'\''s file-editing tools cannot write' \
        '> through symlinks and will throw an error.' \
        '>' \
        '> **DO NOT** attempt to write to or edit `AGENTS.md` in the' \
        '> project root. If you need to update these instructions, you **MUST write' \
        '> directly to `AGENTS/AGENTS.md`**.'
end
