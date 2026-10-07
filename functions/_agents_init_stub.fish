# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_init_stub [--public | --local] [REL]
#
# DESCRIPTION
#   Prints one of the instruction files agents-init writes for a directory
#   with no instructions of its own. One source for each text:
#   agents-init writes them, and agents-cleanup compares against them byte
#   for byte to recognize a file that never held user content.
#
#   With no option, the private-mode stub: a heading and a directive
#   telling agents to edit AGENTS/AGENTS.md rather than the root symlink.
#
#   --public prints the public-mode starter AGENTS.md: a heading and a
#   "Context & Sub-rules" section that points at AGENTS.local.md, both as an
#   @ import (which Claude Code expands) and as a plain sentence (which
#   agents that do not expand imports still follow). REL, when given and not
#   ".", names a subdirectory and goes in the heading.
#
#   --local prints the public-mode private stub, AGENTS/<REL>/AGENTS.local.md:
#   a directive telling agents to edit the real file in AGENTS/ rather than
#   the AGENTS.local.md symlink, and a note that the file is never committed
#   to the project.
#
# ARGUMENTS
#   --public  Print the public starter AGENTS.md
#   --local   Print the private AGENTS.local.md stub
#   REL       Directory relative to the project root ("." or omitted for the root)
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The file text, on stdout.
#
# EXAMPLE
#   _agents_init_stub >AGENTS/AGENTS.md
#   _agents_init_stub --public >AGENTS.md
#   _agents_init_stub --local functions >AGENTS/functions/AGENTS.local.md
function _agents_init_stub
    set -l kind private
    if contains -- "$argv[1]" --public --local
        set kind (string sub -s 3 -- $argv[1])
        set -e argv[1]
    end
    set -l rel "$argv[1]"
    test -n "$rel"; or set rel .

    switch $kind
        case private
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
        case public
            set -l heading '# AGENTS.md'
            test "$rel" != .; and set heading "# AGENTS.md — $rel/"
            printf '%s\n' \
                $heading \
                '' \
                'Instructions for AI coding agents working in this repository.' \
                '' \
                '## Context & Sub-rules' \
                '' \
                'Before taking action, read and follow the local, untracked instructions in' \
                '@AGENTS.local.md if that file exists. It holds machine- and maintainer-specific' \
                'rules that are not part of this repository. If it is absent, continue without it.'
        case local
            set -l real AGENTS/AGENTS.local.md
            test "$rel" != .; and set real "AGENTS/$rel/AGENTS.local.md"
            printf '%s\n' \
                '# AGENTS.local.md' \
                '' \
                '> ⚠️ **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' \
                '> You may be reading this file via a symlink (`AGENTS.local.md`) in' \
                '> the project. Your environment'\''s file-editing tools cannot write' \
                '> through symlinks and will throw an error.' \
                '>' \
                '> **DO NOT** attempt to write to or edit the `AGENTS.local.md` symlink.' \
                '> If you need to update these instructions, you **MUST write' \
                '> directly to `'$real'`**.' \
                '' \
                'Private, machine-specific instructions. This file lives in the AGENTS/' \
                'sub-repository and is never committed to the project.'
    end
end
