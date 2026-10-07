# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   _agents_init_stub
#
# CLASSIFICATION
#   self-limiting(rm,mkdir), bypasses-shadow(mv)
#
# SYNOPSIS
#   _agents_init_sync_public <root> <agents_dir> <rel>
#
# DESCRIPTION
#   The public-mode counterpart of _agents_init_sync_instructions: settles
#   one directory's instruction files so that each real file lives in the
#   repository whose visibility matches it.
#
#     <rel>/AGENTS.md                 real, public, tracked by the project
#     AGENTS/<rel>/AGENTS.md          symlink back to the public file
#     AGENTS/<rel>/AGENTS.local.md    real, private, versioned in AGENTS/
#     <rel>/AGENTS.local.md           symlink to the private file (gitignored)
#
#   In order:
#
#   1. The public file. A real <rel>/AGENTS.md is never moved, rewritten
#      or adopted, tracked or not. A missing root file gets the public
#      starter (_agents_init_stub --public); a missing child file stays
#      missing. A <rel>/AGENTS.md that is a symlink into AGENTS/ is a
#      private-mode leftover: this directory is skipped with a warning that
#      points at agents-init --public, never converted silently.
#   2. CLAUDE.md. A tracked one is left alone. An untracked real one is
#      presumed private, so it becomes the mirror's AGENTS.local.md (or is
#      dropped when identical to it) -- never the public file. A leftover
#      symlink is removed.
#   3. The private file. The root gets the local stub when it has none;
#      a child gets one only if the user created AGENTS/<rel>/AGENTS.local.md.
#      A real, untracked <rel>/AGENTS.local.md (an agent wrote it directly)
#      is adopted into the mirror, or dropped when identical to it; when it
#      differs, both are left and a warning goes to stderr.
#   4. Links: <rel>/AGENTS.local.md -> the mirror file, and
#      AGENTS/<rel>/AGENTS.md -> the public file. A real file found at
#      AGENTS/<rel>/AGENTS.md holds private content and is never replaced;
#      a warning goes to stderr.
#
# ARGUMENTS
#   root        Absolute path to the project root
#   agents_dir  Absolute path to the project's AGENTS/ sub-repo
#   rel         Path of the directory being synced, relative to root
#               ("." for the root itself)
#
# EXIT STATUS
#   0  <rel> is settled (including the warned skips)
#   1  A filesystem operation (mkdir/mv/rm/ln) failed
#
# RETURNS
#   One "→ ..." line per change made, on stdout; nothing when <rel> was
#   already settled. Warnings go to stderr.
#
# EXAMPLE
#   _agents_init_sync_public /path/to/project /path/to/project/AGENTS .
function _agents_init_sync_public --argument-names root agents_dir rel
    test -n "$root" -a -n "$agents_dir" -a -n "$rel"; or return 1

    set -l proj_dir "$root"
    set -l mirror_dir "$agents_dir"
    set -l disp ""
    set -l up ""
    if test "$rel" != "."
        set proj_dir "$root/$rel"
        set mirror_dir "$agents_dir/$rel"
        set disp "$rel/"
        set up (string repeat -n (count (string split / -- $rel)) "../")
    end

    set -l proj_pub "$proj_dir/AGENTS.md"
    set -l proj_loc "$proj_dir/AGENTS.local.md"
    set -l proj_claude "$proj_dir/CLAUDE.md"
    set -l mirror_pub "$mirror_dir/AGENTS.md"
    set -l mirror_loc "$mirror_dir/AGENTS.local.md"
    set -l mirror_rel AGENTS/"$disp"
    # Link targets, relative to the link's own directory.
    set -l loc_target "$up""$mirror_rel""AGENTS.local.md"
    set -l pub_target "../$up""$disp""AGENTS.md"

    # ── 1: the public file ──
    if test -L "$proj_pub"
        if string match -q -- '*AGENTS/*' (readlink "$proj_pub")
            echo "_agents_init_sync_public: $disp""AGENTS.md is a private-mode link into AGENTS/; run agents-init --public to migrate it" >&2
            return 0
        end
    else if not test -e "$proj_pub"; and test "$rel" = "."
        _agents_init_stub --public >"$proj_pub"
        or begin
            echo "_agents_init_sync_public: could not write $proj_pub" >&2
            return 1
        end
        echo "→ Created AGENTS.md (public starter)"
    end

    mkdir -p "$mirror_dir"
    or begin
        echo "_agents_init_sync_public: could not create $mirror_dir" >&2
        return 1
    end

    # ── 2: CLAUDE.md -- untracked content is private ──
    if test -L "$proj_claude"
        rm -f "$proj_claude"
        or begin
            echo "_agents_init_sync_public: could not remove $proj_claude" >&2
            return 1
        end
        echo "→ Removed $disp""CLAUDE.md link"
    else if test -f "$proj_claude"
        if git -C "$root" --literal-pathspecs ls-files --error-unmatch -- "$proj_claude" >/dev/null 2>&1
            # Tracked: the project's own file. Not ours to touch.
        else if not test -e "$mirror_loc"; and not test -f "$proj_loc" -a ! -L "$proj_loc"
            command mv "$proj_claude" "$mirror_loc"
            or begin
                echo "_agents_init_sync_public: could not move $proj_claude" >&2
                return 1
            end
            echo "→ Moved $disp""CLAUDE.md → $mirror_rel""AGENTS.local.md (private)"
        else if test -f "$mirror_loc"; and command diff -q "$proj_claude" "$mirror_loc" >/dev/null 2>&1
            rm -f "$proj_claude"
            or begin
                echo "_agents_init_sync_public: could not remove $proj_claude" >&2
                return 1
            end
            echo "→ Removed $disp""CLAUDE.md (identical to $mirror_rel""AGENTS.local.md)"
        else
            echo "_agents_init_sync_public: $proj_claude differs from $mirror_loc; leaving both, resolve by hand" >&2
        end
    end

    # ── 3: the private file ──
    if test -f "$proj_loc"; and not test -L "$proj_loc"
        if not test -e "$mirror_loc"
            command mv "$proj_loc" "$mirror_loc"
            or begin
                echo "_agents_init_sync_public: could not move $proj_loc" >&2
                return 1
            end
            echo "→ Moved $disp""AGENTS.local.md → $mirror_rel""AGENTS.local.md"
        else if command diff -q "$proj_loc" "$mirror_loc" >/dev/null 2>&1
            rm -f "$proj_loc"
            or begin
                echo "_agents_init_sync_public: could not remove $proj_loc" >&2
                return 1
            end
        else
            echo "_agents_init_sync_public: $proj_loc and $mirror_loc differ; leaving both, resolve by hand" >&2
        end
    end
    if test "$rel" = "."; and not test -e "$mirror_loc"; and not test -L "$mirror_loc"
        _agents_init_stub --local >"$mirror_loc"
        or begin
            echo "_agents_init_sync_public: could not write $mirror_loc" >&2
            return 1
        end
        echo "→ Created AGENTS/AGENTS.local.md (private)"
    end

    # ── 4: links ──
    if test -f "$mirror_loc"; and not test -f "$proj_loc" -a ! -L "$proj_loc"
        if not test -L "$proj_loc"; or test (readlink "$proj_loc") != "$loc_target"
            rm -f "$proj_loc"
            ln -s "$loc_target" "$proj_loc"
            or begin
                echo "_agents_init_sync_public: could not link $proj_loc" >&2
                return 1
            end
            echo "→ Linked $disp""AGENTS.local.md → $loc_target"
        end
    end

    if test -f "$proj_pub"; and not test -L "$proj_pub"
        if test -L "$mirror_pub"
            if test (readlink "$mirror_pub") != "$pub_target"
                rm -f "$mirror_pub"
                ln -s "$pub_target" "$mirror_pub"
                or begin
                    echo "_agents_init_sync_public: could not link $mirror_pub" >&2
                    return 1
                end
                echo "→ Relinked $mirror_rel""AGENTS.md → $pub_target"
            end
        else if test -e "$mirror_pub"
            echo "_agents_init_sync_public: $mirror_pub is a real file (private content); not replacing it with a link to the public $disp""AGENTS.md" >&2
        else
            ln -s "$pub_target" "$mirror_pub"
            or begin
                echo "_agents_init_sync_public: could not link $mirror_pub" >&2
                return 1
            end
            echo "→ Linked $mirror_rel""AGENTS.md → $pub_target"
        end
    end

    return 0
end
