# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   _agents_init_stub, _agents_init_sync_public
#
# CLASSIFICATION
#   self-limiting(rm), bypasses-shadow(mv)
#
# SYNOPSIS
#   _agents_init_migrate_public <root> <agents_dir>
#
# DESCRIPTION
#   Converts a private-mode project to public mode. Called by
#   agents-init --public when AGENTS/ already exists and is not public.
#
#   Every real AGENTS/<rel>/AGENTS.md is the project's PRIVATE content, so
#   it stays private: it is renamed in the sub-repo with `git mv` to
#   AGENTS/<rel>/AGENTS.local.md, which keeps its history (git log --follow).
#   If the file carries a SYSTEM DIRECTIVE blockquote naming its old path,
#   the path is rewritten to the new one; otherwise a warning says so.
#
#   The project-level <rel>/AGENTS.md link is replaced by a public starter
#   (_agents_init_stub --public <rel>). No private content is ever copied
#   into a public file: promoting it is the user's deliberate choice. A
#   real <rel>/AGENTS.md already in the project (a tracked file agents-init
#   left alone) is kept as it is. _agents_init_sync_public then creates the
#   links both ways.
#
#   The "AGENTS.md" line in every "Added by agents-init" block of .gitignore
#   becomes "AGENTS.local.md"; lines outside those blocks are the user's and
#   are never edited. AGENTS/.mode is written last, so an interrupted migration is
#   simply re-run. Nothing is committed in the project.
#
#   Preconditions, checked before any change: a git repository, no rebase
#   in progress in AGENTS/, and no staged changes to any AGENTS.md in the
#   project.
#
# ARGUMENTS
#   root        Absolute path to the project root
#   agents_dir  Absolute path to the project's AGENTS/ sub-repo
#
# EXIT STATUS
#   0  Migrated
#   1  A precondition failed (nothing changed) or a step failed
#
# RETURNS
#   One "→ ..." line per change, on stdout. Refusals and warnings go to stderr.
#
# EXAMPLE
#   _agents_init_migrate_public /path/to/project /path/to/project/AGENTS
function _agents_init_migrate_public --argument-names root agents_dir
    test -n "$root" -a -n "$agents_dir"; or return 1

    # ── Preconditions: refuse before the first change ──
    if not git -C "$root" rev-parse --git-dir >/dev/null 2>&1
        echo "_agents_init_migrate_public: not a git repository; public mode needs one" >&2
        return 1
    end
    if test "$(git -C "$agents_dir" rev-parse --git-dir 2>/dev/null)" != .git
        echo "_agents_init_migrate_public: AGENTS/ is not a git repository" >&2
        return 1
    end
    if test -d "$agents_dir/.git/rebase-merge"; or test -d "$agents_dir/.git/rebase-apply"
        echo "_agents_init_migrate_public: AGENTS/ has an unresolved rebase; finish or abort it first" >&2
        return 1
    end
    set -l staged (git -C "$root" diff --cached --name-only -- AGENTS.md '*/AGENTS.md' 2>/dev/null)
    if set -q staged[1]
        echo "_agents_init_migrate_public: staged changes to "(string join ', ' -- $staged)"; commit or unstage them first" >&2
        return 1
    end

    # Every real (non-link) AGENTS.md in the mirror, as a path relative to it.
    set -l rels
    for f in (find "$agents_dir" -name .git -prune -o -name AGENTS.md -type f -print)
        set -l d (path dirname -- "$f")
        if test "$d" = "$agents_dir"
            set -a rels .
        else
            set -a rels (string replace -- "$agents_dir/" "" "$d")
        end
    end

    for rel in $rels
        set -l mdir "$agents_dir"
        set -l pdir "$root"
        set -l disp ""
        if test "$rel" != "."
            set mdir "$agents_dir/$rel"
            set pdir "$root/$rel"
            set disp "$rel/"
        end
        set -l git_rel AGENTS.md
        test "$rel" != "."; and set git_rel "$rel/AGENTS.md"

        if test -e "$mdir/AGENTS.local.md" -o -L "$mdir/AGENTS.local.md"
            echo "_agents_init_migrate_public: AGENTS/$disp""AGENTS.local.md already exists; skipping AGENTS/$git_rel, resolve by hand" >&2
            continue
        end

        # Rename inside the sub-repo; git mv keeps it a rename in history.
        # An untracked mirror file (never committed) is moved plainly.
        if git -C "$agents_dir" ls-files --error-unmatch -- "$git_rel" >/dev/null 2>&1
            git -C "$agents_dir" mv -- "$git_rel" (string replace -r 'AGENTS\.md$' 'AGENTS.local.md' -- "$git_rel")
        else
            command mv "$mdir/AGENTS.md" "$mdir/AGENTS.local.md"
        end
        or begin
            echo "_agents_init_migrate_public: could not rename AGENTS/$git_rel" >&2
            return 1
        end
        echo "→ Renamed AGENTS/$git_rel → AGENTS/$disp""AGENTS.local.md (stays private)"

        # Retarget the edit directive, if the file has one naming the old path.
        set -l local "$mdir/AGENTS.local.md"
        set -l old_tok "`AGENTS/$git_rel`"
        set -l new_tok "`AGENTS/$disp""AGENTS.local.md`"
        if _agents_init_stub | cmp -s - "$local"
            _agents_init_stub --local $rel >"$local"
            echo "→ Replaced the stub directive in AGENTS/$disp""AGENTS.local.md"
        else if grep -qF -- "$old_tok" "$local"
            set -l body (string replace -a -- "$old_tok" "$new_tok" <"$local")
            printf '%s\n' $body >"$local"
            or begin
                echo "_agents_init_migrate_public: could not rewrite $local" >&2
                return 1
            end
            echo "→ Retargeted the edit directive in AGENTS/$disp""AGENTS.local.md"
        else if grep -qF 'SYSTEM DIRECTIVE' "$local"
            echo "_agents_init_migrate_public: AGENTS/$disp""AGENTS.local.md has an edit directive that does not name AGENTS/$git_rel; check it by hand" >&2
        end

        # The project side: replace the private-mode link with a public starter.
        set -l pfile "$pdir/AGENTS.md"
        if test -L "$pfile"
            rm -f "$pfile"
            or begin
                echo "_agents_init_migrate_public: could not remove $pfile" >&2
                return 1
            end
        end
        if not test -e "$pfile"
            mkdir -p "$pdir"
            _agents_init_stub --public $rel >"$pfile"
            or begin
                echo "_agents_init_migrate_public: could not write $pfile" >&2
                return 1
            end
            echo "→ Created $disp""AGENTS.md (public starter -- review before committing)"
        end

        set -l out (_agents_init_sync_public "$root" "$agents_dir" "$rel")
        or return 1
        test -n "$out"; and printf '%s\n' $out
    end

    # ── .gitignore: AGENTS.md is public now ──
    set -l gitignore "$root/.gitignore"
    if test -f "$gitignore"; and grep -q 'Added by agents-init' "$gitignore"
        set -l kept (awk '
            /^#.*Added by agents-init/ { inblk = 1; print; next }
            inblk && /^#[ \t]*(─)+[ \t]*$/ { inblk = 0; print; next }
            inblk && $0 == "AGENTS.md" { print "AGENTS.local.md"; next }
            { print }' "$gitignore")
        if test "$(printf '%s\n' $kept | string collect)" != "$(string collect <"$gitignore")"
            printf '%s\n' $kept >"$gitignore"
            or begin
                echo "_agents_init_migrate_public: could not rewrite .gitignore" >&2
                return 1
            end
            echo "→ Replaced AGENTS.md with AGENTS.local.md in the agents-init .gitignore block"
        end
    end

    printf '%s\n' public >"$agents_dir/.mode"
    or begin
        echo "_agents_init_migrate_public: could not write AGENTS/.mode" >&2
        return 1
    end
    echo "→ Marked AGENTS/ as public mode"
    return 0
end
