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
#   and the other is removed; a link to a target holding only .gitkeep is
#   removed with nothing put in its place. An AGENTS.md that is exactly
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
#   discards them instead.
#
#   The disabled marker is the per-clone git config key
#   agents-init.disabled, set on every run. --marker-file also writes
#   .agents-disabled in the project root, which agents-init honors too and
#   which may be committed to opt every clone out; it is the only marker
#   available outside a git repository. In a project with no AGENTS/, only
#   the marker is set -- a pre-emptive opt-out. agents-init --enable
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
#      AGENTS/, unlinked files in AGENTS/) or a step failed
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
    if test -d "$agents_dir"
        set has_agents 1
        # Resolved, because link targets are compared after realpath, which
        # also resolves any symlinked parent of $root.
        set agents_dir (realpath -- "$agents_dir")
        test -d "$agents_dir/.git"; and set has_repo 1
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
    if test $has_agents -eq 1
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
    if test $has_agents -eq 1
        set -l cover_re
        for t in $keep_tgt
            set -a cover_re '^'(string escape --style=regex -- "$t")'(/|$)'
        end
        for f in (find "$agents_dir" -path "$agents_dir/.git" -prune -o ! -type d -print)
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

    if set -q extras[1]; and not set -q _flag_drop_extras
        echo "$c_err""Error: AGENTS/ holds files no project symlink points to:$c_reset" >&2
        for e in $extras
            if contains -- "$e" $extras_ignored
                echo "  AGENTS/$e  (ignored -- not in bundle)" >&2
            else
                echo "  AGENTS/$e" >&2
            end
        end
        echo "Move them out of AGENTS/ by hand, or re-run with --drop-extras (the history bundle keeps every file not marked ignored)." >&2
        return 1
    end

    set -l state_dir $XDG_STATE_HOME
    test -n "$state_dir"; or set state_dir "$HOME/.local/state"
    set -l bundle "$state_dir/agents-cleanup/"(_agents_repo_slug "$root")"-"(date +%Y%m%d-%H%M%S)".bundle"
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
        set -l cur (git -C "$root" config --type=bool --get agents-init.disabled 2>/dev/null)
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

    #   ────────────────────────────── Summary ───────────────────────────────
    if test $changed -eq 0
        test $verbose -eq 1; and echo "$c_dim→ Nothing to clean up; agents-init is already disabled here$c_reset"
    else if test $quiet -eq 1
        if test -n "$archived"
            echo "$c_ok→ Cleaned up AGENTS scaffolding (history: $archived)$c_reset"
        else
            echo "$c_ok→ Cleaned up AGENTS scaffolding$c_reset"
        end
    end
    return 0
end
