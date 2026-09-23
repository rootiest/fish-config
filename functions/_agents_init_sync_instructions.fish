# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm,mkdir), bypasses-shadow(mv)
#
# SYNOPSIS
#   _agents_init_sync_instructions <root> <agents_dir> <rel>
#
# DESCRIPTION
#   Normalizes one directory's agent instruction file(s) into the
#   AGENTS.md-only shape: <root>/<rel>/AGENTS.md becomes a symlink to the
#   real file at <agents_dir>/<rel>/AGENTS.md (or, for the root itself,
#   <agents_dir>/AGENTS.md directly), and no CLAUDE.md survives anywhere
#   for that directory -- neither at the project level nor inside the
#   mirror.
#
#   Four states of <rel> are handled, in order, so later steps only ever
#   see a settled mirror:
#
#   1. The mirror itself is inverted (CLAUDE.md real, AGENTS.md symlinked
#      to it). Flipped in place: same bytes, new name.
#   2. The mirror has no real AGENTS.md yet, and the project directory
#      has one or both files. A lone real file (either name) is adopted
#      as the mirror's AGENTS.md -- a lone CLAUDE.md is renamed, never
#      preserved under its own name. Both real and byte-identical: the
#      AGENTS.md side is adopted and the duplicate CLAUDE.md is dropped.
#      Both real and different: neither is touched and a warning is
#      printed to stderr -- this function has no way to know which side
#      is authoritative, and silently keeping one would silently discard
#      the other.
#   3. Any CLAUDE.md still left in the mirror once AGENTS.md is settled
#      (belt-and-suspenders past step 1) is removed.
#   4. The project-level AGENTS.md symlink is (re)created if missing or
#      stale, and any CLAUDE.md left at the project level is removed.
#
# ARGUMENTS
#   root        Absolute path to the project root
#   agents_dir  Absolute path to the project's AGENTS/ sub-repo
#   rel         Path of the directory being synced, relative to root
#               ("." for the root itself)
#
# EXIT STATUS
#   0  <rel> is settled (including the both-real-and-different skip, which
#      is not a failure of this function)
#   1  A filesystem operation (mkdir/mv/rm/ln) failed
#
# RETURNS
#   One "→ ..." line per change made, on stdout; nothing when <rel> was
#   already settled. A skip warning goes to stderr, never stdout, so it is
#   never mistaken for a change.
#
# EXAMPLE
#   _agents_init_sync_instructions /path/to/project /path/to/project/AGENTS .
#   _agents_init_sync_instructions /path/to/project /path/to/project/AGENTS functions
function _agents_init_sync_instructions --argument-names root agents_dir rel
    test -n "$root" -a -n "$agents_dir" -a -n "$rel"; or return 1

    set -l proj_dir "$root"
    set -l mirror_dir "$agents_dir"
    if test "$rel" != "."
        set proj_dir "$root/$rel"
        set mirror_dir "$agents_dir/$rel"
    end

    set -l proj_agents "$proj_dir/AGENTS.md"
    set -l proj_claude "$proj_dir/CLAUDE.md"
    set -l mirror_agents "$mirror_dir/AGENTS.md"
    set -l mirror_claude "$mirror_dir/CLAUDE.md"

    # Display names for progress lines: bare at the root, "<rel>/..." below it.
    set -l disp_agents AGENTS.md
    set -l disp_claude CLAUDE.md
    set -l mirror_rel AGENTS
    if test "$rel" != "."
        set disp_agents "$rel/AGENTS.md"
        set disp_claude "$rel/CLAUDE.md"
        set mirror_rel "AGENTS/$rel"
    end

    mkdir -p "$mirror_dir"
    or begin
        echo "_agents_init_sync_instructions: could not create $mirror_dir" >&2
        return 1
    end

    # ── 1: an inverted mirror (CLAUDE.md real, AGENTS.md symlinked to it) ──
    if test -f "$mirror_claude"; and not test -L "$mirror_claude"
        if test -L "$mirror_agents"
            rm -f "$mirror_agents"
            or begin
                echo "_agents_init_sync_instructions: could not remove $mirror_agents" >&2
                return 1
            end
        end
        if not test -e "$mirror_agents"
            command mv "$mirror_claude" "$mirror_agents"
            or begin
                echo "_agents_init_sync_instructions: could not rename $mirror_claude" >&2
                return 1
            end
            echo "→ Renamed $mirror_rel/CLAUDE.md → AGENTS.md"
        end
    end

    # ── 2: adopt real project-level files, only if the mirror has none yet ──
    if not test -f "$mirror_agents"
        set -l has_agents 0
        set -l has_claude 0
        test -f "$proj_agents"; and not test -L "$proj_agents"; and set has_agents 1
        test -f "$proj_claude"; and not test -L "$proj_claude"; and set has_claude 1

        if test $has_agents -eq 1; and test $has_claude -eq 1
            if command diff -q "$proj_agents" "$proj_claude" >/dev/null 2>&1
                command mv "$proj_agents" "$mirror_agents"
                or begin
                    echo "_agents_init_sync_instructions: could not move $proj_agents" >&2
                    return 1
                end
                rm -f "$proj_claude"
                or begin
                    echo "_agents_init_sync_instructions: could not remove $proj_claude" >&2
                    return 1
                end
                echo "→ Moved $disp_agents → $mirror_rel/AGENTS.md (dropped identical CLAUDE.md)"
            else
                echo "_agents_init_sync_instructions: $proj_agents and $proj_claude differ; leaving both, resolve by hand" >&2
                return 0
            end
        else if test $has_agents -eq 1
            command mv "$proj_agents" "$mirror_agents"
            or begin
                echo "_agents_init_sync_instructions: could not move $proj_agents" >&2
                return 1
            end
            echo "→ Moved $disp_agents → $mirror_rel/AGENTS.md"
        else if test $has_claude -eq 1
            command mv "$proj_claude" "$mirror_agents"
            or begin
                echo "_agents_init_sync_instructions: could not move $proj_claude" >&2
                return 1
            end
            echo "→ Moved $disp_claude → $mirror_rel/AGENTS.md"
        else if test "$rel" = "."
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
                '> directly to `AGENTS/AGENTS.md`**.' >"$mirror_agents"
            echo "→ Created AGENTS/AGENTS.md with agent directive"
        end
    end

    # ── 3: the mirror never carries a CLAUDE.md once AGENTS.md is settled ──
    if test -f "$mirror_agents"; and test -e "$mirror_claude" -o -L "$mirror_claude"
        rm -f "$mirror_claude"
        or begin
            echo "_agents_init_sync_instructions: could not remove $mirror_claude" >&2
            return 1
        end
        echo "→ Removed $mirror_rel/CLAUDE.md"
    end

    # Nothing more to do for a conflicted or still-empty directory.
    test -f "$mirror_agents"; or return 0

    # ── 4: ensure the project-level AGENTS.md symlink, drop project CLAUDE.md ──
    set -l target "AGENTS/AGENTS.md"
    if test "$rel" != "."
        set -l up (string repeat -n (count (string split / -- $rel)) "../")
        set target "$up""AGENTS/$rel/AGENTS.md"
    end
    set -l need_link 1
    if test -L "$proj_agents"
        test (readlink "$proj_agents") = "$target"; and set need_link 0
    end
    if test $need_link -eq 1
        rm -f "$proj_agents"
        ln -s "$target" "$proj_agents"
        or begin
            echo "_agents_init_sync_instructions: could not link $proj_agents" >&2
            return 1
        end
        echo "→ Linked $disp_agents → $target"
    end

    if test -e "$proj_claude" -o -L "$proj_claude"
        rm -f "$proj_claude"
        or begin
            echo "_agents_init_sync_instructions: could not remove $proj_claude" >&2
            return 1
        end
        echo "→ Removed $disp_claude"
    end

    return 0
end
