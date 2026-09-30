# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# DEPENDENCIES
#   _agents_init_find, _agents_init_stub, _agents_repo_slug, _agents_repo_sync
#
# CLASSIFICATION
#   destructive, self-limiting(rm,mkdir,grep), bypasses-shadow(mv), manual-section(16-agent-tooling)
#
# SYNOPSIS
#   agents-cleanup [-n | --dry-run] [--drop-extras] [--marker-file]
#                  [-v | --verbose] [-q | --quiet] [-s | --silent] [-h | --help]
#
# DESCRIPTION
#   Reverses agents-init in the current project, and marks the project so
#   agents-init -- and therefore every claude/agy launch -- leaves it
#   alone from then on.
#
#   Every symlink that resolves into AGENTS/ is replaced by the real file
#   or directory it points to. When two links share a target (docs/plans
#   and docs/superpowers/plans), the shallower one receives the content
#   and the other is removed; a link to a target holding only .gitkeep, a
#   dangling link, or a link to AGENTS/ itself is removed with nothing put
#   in its place. Dangling links are removed even when AGENTS/ is already
#   gone. An AGENTS.md that is exactly
#   the stub agents-init writes is deleted; any other AGENTS.md loses only
#   the SYSTEM DIRECTIVE blockquote that pointed agents at AGENTS/AGENTS.md.
#   No CLAUDE.md is recreated.
#
#   Before anything is moved, pending AGENTS/ changes are committed and
#   the full history is written to a verified git bundle under
#   $XDG_STATE_HOME/agents-cleanup/ (default ~/.local/state). AGENTS/ is
#   then removed, along with docs/superpowers/ and docs/ if left empty,
#   and every "Added by agents-init" block is stripped from .gitignore.
#   Nothing is committed to the outer repository.
#
#   Files inside AGENTS/ that no project symlink points to -- other than
#   agents-init's own .version, .agents-tools/ and .gitkeep files -- stop
#   the cleanup before anything changes. They are listed; --drop-extras
#   discards them instead. A nested git repository inside AGENTS/ is always
#   refused, --drop-extras or not: the bundle keeps only a pointer to it, so
#   move it out first.
#
#   The disabled marker is the per-clone git config key
#   agents-init.disabled, set on every run. --marker-file also writes
#   .agents-disabled in the project root, which agents-init honors too and
#   which may be committed to opt every clone out; it is the only marker
#   available outside a git repository, where the project root is taken to
#   be the current directory -- run it from there. In a project with no
#   AGENTS/, only the marker is set -- a pre-emptive opt-out. agents-init --enable
#   clears the git key again.
#
#   Re-running is safe: an interrupted cleanup resumes where it stopped,
#   and a finished one only confirms the marker.
#
# ARGUMENTS
#   -n, --dry-run    Print the plan and change nothing
#   --drop-extras    Discard unlinked files in AGENTS/ instead of refusing
#   --marker-file    Also write .agents-disabled (required outside git)
#   -v, --verbose    Print all per-step output (default)
#   -q, --quiet      Print one summary line only if changes were made
#   -s, --silent     Suppress all output; errors only
#   -h, --help       Show this help message and exit
#
# EXIT STATUS
#   0  Cleanup finished, or nothing was left to do
#   1  Refused (outside git without --marker-file, unresolved rebase in
#      AGENTS/, unlinked files or a nested repository in AGENTS/) or a step
#      failed
#
# EXAMPLE
#   agents-cleanup --dry-run
#   agents-cleanup
#   agents-cleanup --marker-file
#
# NOTES
#   Restore an archived AGENTS/ with: git clone <bundle> AGENTS, then
#   agents-init --enable. The full write-up -- what is kept, what is
#   removed, and how the markers interact -- is in
#   docs/manual/16-agent-tooling.md. Update that section in the same
#   change whenever this function's behavior changes.
function agents-cleanup --description 'undo agents-init: restore real files, archive and remove AGENTS/, disable agents-init'
    __fish_palette

    argparse h/help n/dry-run drop-extras marker-file v/verbose q/quiet s/silent -- $argv
    or return 1

    if set -q _flag_help
        echo "$c_head""Usage:$c_reset $c_cmd""agents-cleanup$c_reset $c_flag""[-n] [--drop-extras] [--marker-file] [-v] [-q] [-s] [-h | --help]$c_reset"
        echo
        echo "  Undo agents-init here: restore real files, archive and remove AGENTS/,"
        echo "  and stop agents-init from scaffolding this project again."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset       Show this help message"
        echo "  $c_flag-n$c_reset, $c_flag--dry-run$c_reset    Print the plan and change nothing"
        echo "      $c_flag--drop-extras$c_reset  Discard unlinked files in AGENTS/ instead of refusing"
        echo "      $c_flag--marker-file$c_reset  Also write .agents-disabled (required outside git)"
        echo "  $c_flag-v$c_reset, $c_flag--verbose$c_reset    Print all per-step output (default)"
        echo "  $c_flag-q$c_reset, $c_flag--quiet$c_reset      Print one summary line only if changes were made"
        echo "  $c_flag-s$c_reset, $c_flag--silent$c_reset     Suppress all output; only errors are printed"
        echo
        echo "  Re-enable later with $c_cmd""agents-init --enable$c_reset."
        return 0
    end

    set -l verbose 1
    set -l quiet 0
    if set -q _flag_silent
        set verbose 0
    else if set -q _flag_quiet
        set verbose 0
        set quiet 1
    end

    #   ──────────────────────────── Project root ────────────────────────────
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    set -l in_git 1
    if test -z "$root"
        set in_git 0
        if not set -q _flag_marker_file
            echo "$c_err""Error: not a git repository, so there is no .git/config to hold the marker; re-run with --marker-file to write .agents-disabled instead$c_reset" >&2
            return 1
        end
        set root (pwd)
    end

    #   ──────────────────────── Phase 1: preflight ─────────────────────────
    # Read-only. Every refusal below returns before the first change.
    set -l agents_dir "$root/AGENTS"
    set -l has_agents 0
    set -l has_repo 0
    if test -L "$agents_dir"
        echo "$c_err""Error: AGENTS is a symlink to "(readlink "$agents_dir")"; replace it with a real directory (or remove the link) first$c_reset" >&2
        return 1
    end
    if test -d "$agents_dir"
        set has_agents 1
        # Resolved, because link targets are compared after realpath, which
        # also resolves any symlinked parent of $root.
        set agents_dir (realpath -- "$agents_dir")
        # A .git that is not a valid gitdir (half-removed) is "not a repository";
        # git would otherwise resolve to the enclosing project.
        test "$(git -C "$agents_dir" rev-parse --git-dir 2>/dev/null)" = .git; and set has_repo 1
    end

    if test $has_repo -eq 1
        if test -d "$agents_dir/.git/rebase-merge"; or test -d "$agents_dir/.git/rebase-apply"
            echo "$c_err""Error: AGENTS/ has an unresolved rebase; finish or abort it first$c_reset" >&2
            return 1
        end
    end

    # Links into AGENTS/, shallowest first (then lexical): when two links
    # share a target, the original location -- docs/plans rather than
    # docs/superpowers/plans -- is the one that receives the content.
    set -l keep # links to materialize
    set -l keep_tgt # their resolved targets, index-aligned with $keep
    set -l drop # links removed with nothing put in their place
    # Also runs with no AGENTS/ (deleted by hand): every such link then
    # dangles and is dropped. Not outside git, though: there (pwd) is only a
    # guess at the project root, so without an AGENTS/ in it the walk could
    # cover an arbitrary tree.
    if test $has_agents -eq 1; or test $in_git -eq 1
        test $has_agents -eq 1; or set agents_dir (realpath -m -- "$agents_dir")
        set -l agents_re '^'(string escape --style=regex -- "$agents_dir")'(/|$)'
        set -l links
        for l in (_agents_init_find "$root" -type l -print)
            string match -qr -- $agents_re (realpath -m -- "$l"); and set -a links "$l"
        end
        set links (for l in $links
                printf '%s\t%s\n' (count (string split / -- "$l")) "$l"
            end | sort -t\t -k1,1n -k2 | string replace -r '^\d+\t' '')

        for l in $links
            set -l t (realpath -m -- "$l")
            if not test -e "$t"
                set -a drop "$l" # dangling
            else if test "$t" = "$agents_dir"
                # A link to AGENTS/ itself: materializing it would move the
                # whole repository. Drop-only, like any link with nothing to restore.
                set -a drop "$l"
            else if contains -- "$t" $keep_tgt
                set -a drop "$l" # duplicate of a shallower link
            else if test -d "$t"; and test -z "$(find "$t" ! -type d ! -name .gitkeep -print -quit)"
                set -a drop "$l" # only .gitkeep: nothing to restore
            else
                set -a keep "$l"
                set -a keep_tgt "$t"
            end
        end
    end

    # Files in AGENTS/ that no kept link carries out, minus agents-init's
    # own tooling. Refused by default: nothing says where they belong.
    set -l extras
    set -l extras_ignored
    set -l nested
    if test $has_agents -eq 1
        set -l cover_re
        for t in $keep_tgt
            set -a cover_re '^'(string escape --style=regex -- "$t")'(/|$)'
        end
        # A nested repository is recorded by `git add -A` as a bare gitlink,
        # so neither the bundle nor --drop-extras treats it as files: it is
        # listed on its own and never walked into.
        for f in (find "$agents_dir" -mindepth 1 -name .git -prune -o -type d -exec test -e '{}/.git' \; -print -prune)
            set -l covered 0
            for re in $cover_re
                if string match -qr -- $re "$f"
                    set covered 1
                    break
                end
            end
            test $covered -eq 1; or set -a nested (string replace -- "$agents_dir/" "" "$f")
        end
        for f in (find "$agents_dir" -mindepth 1 \( -name .git -o -type d -exec test -e '{}/.git' \; \) -prune -o ! -type d -print)
            set -l rel (string replace -- "$agents_dir/" "" "$f")
            switch "$rel"
                case .version '.agents-tools/*' .gitkeep '*/.gitkeep'
                    continue
            end
            set -l covered 0
            for re in $cover_re
                if string match -qr -- $re "$f"
                    set covered 1
                    break
                end
            end
            test $covered -eq 1; and continue
            set -a extras "$rel"
            if test $has_repo -eq 1; and git -C "$agents_dir" check-ignore -q -- "$rel" 2>/dev/null
                set -a extras_ignored "$rel"
            end
        end
    end

    if set -q nested[1]
        echo "$c_err""Error: AGENTS/ holds nested git repositories; the history bundle records only a pointer to them, so they would be lost:$c_reset" >&2
        for n in $nested
            echo "  AGENTS/$n/  (nested repository -- not in bundle)" >&2
        end
        echo "Move them out of AGENTS/ first; --drop-extras does not cover them." >&2
        return 1
    end

    if set -q extras[1]; and not set -q _flag_drop_extras
        echo "$c_err""Error: AGENTS/ holds files no project symlink points to:$c_reset" >&2
        for e in $extras
            if contains -- "$e" $extras_ignored
                echo "  AGENTS/$e  (ignored -- not in bundle)" >&2
            else if test $has_repo -eq 0
                echo "  AGENTS/$e  (not in bundle)" >&2
            else
                echo "  AGENTS/$e" >&2
            end
        end
        if test $has_repo -eq 1
            echo "Move them out of AGENTS/ by hand, or re-run with --drop-extras (the history bundle keeps every file not marked ignored)." >&2
        else
            echo "Move them out of AGENTS/ by hand, or re-run with --drop-extras (AGENTS/ is not a git repository, so there is no bundle and they are lost)." >&2
        end
        return 1
    end

    set -l state_dir $XDG_STATE_HOME
    test -n "$state_dir"; or set state_dir "$HOME/.local/state"
    set -l bundle_base "$state_dir/agents-cleanup/"(_agents_repo_slug "$root")"-"(date +%Y%m%d-%H%M%S)
    # `git bundle create` overwrites: never reuse a name from the same second.
    set -l bundle "$bundle_base.bundle"
    set -l n 0
    while test -e "$bundle"
        set n (math $n + 1)
        set bundle "$bundle_base-$fish_pid-$n.bundle"
    end
    set -l gitignore "$root/.gitignore"

    if set -q _flag_dry_run
        set -q _flag_silent; and return 0
        echo "$c_head""Dry run -- nothing changed. Plan:$c_reset"
        test $in_git -eq 1; and echo "  set git config agents-init.disabled true"
        set -q _flag_marker_file; and echo "  write .agents-disabled"
        test $has_repo -eq 1; and echo "  archive AGENTS/ history to $bundle"
        for i in (seq (count $keep))
            echo "  restore "(string replace -- "$root/" "" "$keep[$i]")" from AGENTS/"(string replace -- "$agents_dir/" "" "$keep_tgt[$i]")
        end
        for l in $drop
            echo "  remove link "(string replace -- "$root/" "" "$l")
        end
        for e in $extras
            echo "  discard AGENTS/$e"
        end
        test $has_agents -eq 1; and echo "  remove AGENTS/"
        if test -f "$gitignore"; and grep -q 'Added by agents-init' "$gitignore"
            echo "  remove agents-init blocks from .gitignore"
        end
        return 0
    end

    #   ─────────────────────────── Phase 2: mark ───────────────────────────
    # Before any destructive step: a claude/agy launch mid-cleanup must not
    # re-scaffold, and a re-run after a failure resumes instead of fighting
    # agents-init.
    set -l changed 0
    set -l archived
    if test $in_git -eq 1
        set -l cur (git -C "$root" config --local --type=bool --get agents-init.disabled 2>/dev/null)
        if test "$cur" != true
            if not git -C "$root" config --local agents-init.disabled true
                echo "$c_err""Error: could not set git config agents-init.disabled$c_reset" >&2
                return 1
            end
            set changed 1
            test $verbose -eq 1; and echo "$c_ok→ Set git config agents-init.disabled true$c_reset"
        end
    end
    if set -q _flag_marker_file; and not test -e "$root/.agents-disabled"
        if not printf '%s\n' \
                '# agents-init skips this project while this file exists.' \
                '# Written by agents-cleanup. Commit it to opt every clone out;' \
                '# delete it (and commit the deletion) to re-enable.' >"$root/.agents-disabled"
            echo "$c_err""Error: could not write .agents-disabled$c_reset" >&2
            return 1
        end
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Wrote .agents-disabled$c_reset"
    end

    #   ────────────────────────── Phase 3: archive ─────────────────────────
    # Nothing is moved until the history is safely out of AGENTS/.
    if test $has_repo -eq 1
        # 2>/dev/null: the helper's own message would leak past --silent (a
        # command substitution's stderr ignores the caller's redirect); the
        # error below says the same thing.
        set -l sync_out (_agents_repo_sync "$agents_dir" "chore: final sync before agents-cleanup" 2>/dev/null)
        if test $status -ne 0
            echo "$c_err""Error: could not commit pending AGENTS/ changes; nothing moved or removed$c_reset" >&2
            return 1
        end
        if test -n "$sync_out"
            set changed 1
            test $verbose -eq 1; and echo "$c_ok$sync_out$c_reset"
        end

        if git -C "$agents_dir" rev-parse -q --verify HEAD >/dev/null
            if not mkdir -p (path dirname "$bundle")
                echo "$c_err""Error: could not create "(path dirname "$bundle")"; nothing moved or removed$c_reset" >&2
                return 1
            end
            if not git -C "$agents_dir" bundle create -q "$bundle" --all 2>/dev/null
                echo "$c_err""Error: could not write $bundle; nothing moved or removed$c_reset" >&2
                return 1
            end
            if not git -C "$agents_dir" bundle verify -q "$bundle" >/dev/null 2>&1
                echo "$c_err""Error: $bundle failed verification; nothing moved or removed$c_reset" >&2
                return 1
            end
            set changed 1
            set archived "$bundle"
            if test $verbose -eq 1
                echo "$c_ok→ Archived AGENTS/ history to $bundle$c_reset"
                echo "$c_dim  restore with: git clone $bundle AGENTS$c_reset"
            end
        else
            test $verbose -eq 1; and echo "$c_dim→ AGENTS/ has no commits; nothing to archive$c_reset"
        end
    else if test $has_agents -eq 1
        test $verbose -eq 1; and echo "$c_dim→ AGENTS/ is not a git repository; nothing to archive$c_reset"
    end

    #   ──────────────────────── Phase 4: materialize ───────────────────────
    set -l directive 'SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING'
    for i in (seq (count $keep))
        set -l link $keep[$i]
        set -l rel (string replace -- "$root/" "" "$link")
        set -l was (readlink "$link")
        if not test -e "$keep_tgt[$i]"
            echo "$c_err""Error: AGENTS/ target for $rel is missing; nothing changed for it$c_reset" >&2
            return 1
        end
        if not rm -f "$link"
            echo "$c_err""Error: could not restore $rel from AGENTS/; re-run to resume$c_reset" >&2
            return 1
        end
        if not command mv "$keep_tgt[$i]" "$link"
            # Put the link back: without it the target looks like an unlinked
            # extra and a re-run would refuse.
            if ln -s -- "$was" "$link"
                echo "$c_err""Error: could not restore $rel from AGENTS/; link left in place$c_reset" >&2
            else
                set -l where "AGENTS/"(string replace -- "$agents_dir/" "" "$keep_tgt[$i]")
                test -n "$archived"; and set where "$where and in the bundle"
                echo "$c_err""Error: could not restore $rel and could not put its link back; the content is still at $where$c_reset" >&2
            end
            return 1
        end
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Restored $rel$c_reset"

        if test -d "$link"
            rm -f "$link/.gitkeep"
        else if test (path basename "$link") = AGENTS.md
            if _agents_init_stub | cmp -s - "$link"
                rm -f "$link"
                test $verbose -eq 1; and echo "$c_ok→ Removed $rel (agents-init stub, no user content)$c_reset"
            else if grep -qF -- "$directive" "$link"
                # Drop the first run of '>' lines carrying the directive, and
                # the blank lines after it. Not "the first lines": real files
                # put a heading above it.
                set -l body (awk -v d="$directive" '
                    { line[NR] = $0 }
                    END {
                        s = 0
                        for (i = 1; i <= NR; i++) {
                            if (line[i] !~ /^>/) continue
                            j = i; hit = 0
                            while (j <= NR && line[j] ~ /^>/) { if (index(line[j], d)) hit = 1; j++ }
                            if (hit) { s = i; e = j; break }
                            i = j
                        }
                        if (!s) { for (i = 1; i <= NR; i++) print line[i]; exit }
                        while (e <= NR && line[e] ~ /^[ \t]*$/) e++
                        for (i = 1; i < s; i++) print line[i]
                        for (i = e; i <= NR; i++) print line[i]
                    }' "$link")
                if test $status -ne 0
                    echo "$c_err""Error: could not rewrite $rel$c_reset" >&2
                    return 1
                end
                if set -q body[1]; and string match -qr -- '\S' $body
                    if test "$(printf '%s\n' $body | string collect)" != "$(string collect <"$link")"
                        if not printf '%s\n' $body >"$link"
                            echo "$c_err""Error: could not rewrite $rel$c_reset" >&2
                            return 1
                        end
                        test $verbose -eq 1; and echo "$c_ok→ Removed the AGENTS/ directive from $rel$c_reset"
                    end
                else
                    rm -f "$link"
                    test $verbose -eq 1; and echo "$c_ok→ Removed $rel (only the directive, no user content)$c_reset"
                end
            end
        end
    end

    for link in $drop
        set -l rel (string replace -- "$root/" "" "$link")
        if not rm -f "$link"
            echo "$c_err""Error: could not remove link $rel$c_reset" >&2
            return 1
        end
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Removed link $rel$c_reset"
    end

    #   ─────────────────────── Phase 5: remove AGENTS/ ─────────────────────
    if test $has_agents -eq 1
        if not rm -rf "$agents_dir"
            echo "$c_err""Error: could not remove AGENTS/$c_reset" >&2
            return 1
        end
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Removed AGENTS/$c_reset"
    end
    # agents-init creates these; drop them only if nothing else lives there.
    # Also after dropping links with no AGENTS/ left, which empties them too.
    if test $has_agents -eq 1; or set -q drop[1]
        for d in "$root/docs/superpowers" "$root/docs"
            if test -d "$d"; and rmdir "$d" 2>/dev/null
                test $verbose -eq 1; and echo "$c_ok→ Removed empty "(string replace -- "$root/" "" "$d")"/$c_reset"
            end
        end
    end

    #   ───────────────────────── Phase 6: .gitignore ───────────────────────
    # Matched by pattern, not the exact strings _agents_init_ensure_gitignore
    # writes, so blocks from older header variants go too. A header with no
    # footer before the next header is left in place (and reported).
    if test -f "$gitignore"; and grep -q 'Added by agents-init' "$gitignore"
        # The unterminated-block warning is verbose-only, so a quiet or silent
        # re-run stays silent. awk writes /dev/stderr itself: a fish-level
        # 2>/dev/stderr reopens the path, which truncates a log file when
        # stderr is one (`agents-cleanup &>log`).
        set -l kept (awk -v warn=$verbose '
            { line[NR] = $0 }
            END {
                n = 0
                for (i = 1; i <= NR; i++) {
                    if (line[i] ~ /^#.*Added by agents-init/) {
                        for (j = i + 1; j <= NR; j++) {
                            if (line[j] ~ /Added by agents-init/) { j = NR + 1; break }
                            if (line[j] ~ /^#[ \t]*(─)+[ \t]*$/) break
                        }
                        if (j <= NR) {
                            if (n > 0 && out[n] ~ /^[ \t]*$/) n--
                            i = j
                            continue
                        }
                        if (warn) print "agents-cleanup: unterminated agents-init block in .gitignore left in place" > "/dev/stderr"
                    }
                    out[++n] = line[i]
                }
                for (i = 1; i <= n; i++) print out[i]
            }' "$gitignore")
        if test $status -ne 0
            echo "$c_err""Error: could not rewrite .gitignore$c_reset" >&2
            return 1
        end
        # Identical output means only unterminated blocks were found: nothing
        # to write, nothing to report, and a re-run stays silent.
        if test "$(printf '%s\n' $kept | string collect)" != "$(string collect <"$gitignore")"
            if set -q kept[1]; and string match -qr -- '\S' $kept
                if not printf '%s\n' $kept >"$gitignore"
                    echo "$c_err""Error: could not rewrite .gitignore$c_reset" >&2
                    return 1
                end
            else if test $in_git -eq 1; and git -C "$root" ls-files --error-unmatch -- .gitignore >/dev/null 2>&1
                # Tracked: someone committed it, so it is not agents-init's to
                # delete. Leave it empty; the change shows in git status.
                if not true >"$gitignore"
                    echo "$c_err""Error: could not rewrite .gitignore$c_reset" >&2
                    return 1
                end
            else
                # Untracked and nothing but agents-init's blocks: agents-init
                # created it.
                rm -f "$gitignore"
            end
            set changed 1
            test $verbose -eq 1; and echo "$c_ok→ Removed agents-init blocks from .gitignore$c_reset"
        end
    end

    #   ────────────────────────────── Summary ───────────────────────────────
    if test $changed -eq 0
        test $verbose -eq 1; and echo "$c_dim→ Nothing to clean up; agents-init is already disabled here$c_reset"
    else if test $quiet -eq 1
        if test -n "$archived"
            echo "$c_ok→ Cleaned up AGENTS scaffolding (history: $archived; restore with: git clone $archived AGENTS)$c_reset"
        else
            echo "$c_ok→ Cleaned up AGENTS scaffolding$c_reset"
        end
    end
    return 0
end
