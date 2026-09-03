# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# DEPENDENCIES
#   _agents_repo_install_tools, _agents_repo_sync, _agents_init_ensure_gitignore
#
# SYNOPSIS
#   agents-init [-a | --agents] [-p | --plugins] [-v | --verbose]
#               [-q | --quiet] [-s | --silent] [-h | --help]
#
# DESCRIPTION
#   Scaffolds an AGENTS/ sub-repository inside a project directory. Creates
#   a self-contained git repo for agent specifications, moves any existing
#   agent-related files into it, and replaces them with symlinks so the outer
#   project never tracks agent files directly.
#
#   File layout after setup:
#     AGENTS/AGENTS.md          canonical agent spec (real file)
#     AGENTS/CLAUDE.md          real file (if CLAUDE.md existed separately)
#                               or symlink → AGENTS.md (single-source case)
#     <root>/AGENTS.md          → AGENTS/AGENTS.md
#     <root>/CLAUDE.md          → AGENTS/CLAUDE.md
#     AGENTS/plans              superpowers plans      (real dir, .gitkeep)
#     AGENTS/specs              superpowers specs      (real dir, .gitkeep)
#     AGENTS/devlogs            agent development logs (real dir, .gitkeep)
#     AGENTS/.version           MAJOR.MINOR.PATCH structure version (seed 1.0.0)
#     AGENTS/.agents-tools/     committed version-bump script + git hook shims
#     docs/superpowers/plans    → ../../AGENTS/plans   (always)
#     docs/superpowers/specs    → ../../AGENTS/specs   (always)
#     docs/plans                → ../AGENTS/plans   (only if docs/plans existed)
#     docs/specs                → ../AGENTS/specs   (only if docs/specs existed)
#     docs/devlogs              → ../AGENTS/devlogs (only if docs/devlogs existed)
#
#   plans/ and specs/ are merged from every legacy location (docs/<tgt>,
#   docs/superpowers/<tgt>, and the old AGENTS/plugins/ layout) into the
#   canonical AGENTS/<tgt>; the AGENTS/plugins/ layer is removed.
#
#   Each AGENTS repo carries a self-contained version bumper wired via
#   core.hooksPath: a pre-commit hook bumps AGENTS/.version on every commit
#   (MINOR when the tracked directory set changes, PATCH otherwise; MAJOR is
#   manual-only), and a prepare-commit-msg hook appends "(vX.Y.Z)" to the
#   commit subject. Each shim then chains (execs) to the global/system
#   core.hooksPath hook of the same name, so this local override does not
#   shadow global hooks (e.g. ggshield, Git LFS). The script/hooks are
#   version-managed from scripts/agents-tools/ and refreshed when their marker
#   is stale.
#
#   Downstream tooling can read AGENTS/.version directly — a changed MINOR
#   field signals a structure change.
#
#   With no flags, runs both --agents and --plugins setup; --agents re-runs
#   only the AGENTS.md / symlink step and --plugins only the plans/specs/
#   devlogs wiring step. Managed paths are added to .gitignore. At the end
#   of every invocation any uncommitted changes inside the sub-repo are
#   auto-committed so agent-made edits are captured automatically. Fully
#   idempotent: a second run produces no output and no new commits.
#
#   The commit is local only. Nothing here fetches or pushes: the wrappers
#   call this synchronously before starting an agent, and a network round
#   trip there blocks the launch until an unreachable remote times out and
#   can prompt for credentials with nobody watching. A sub-repo that has an
#   upstream is pulled by hand, on the user's own schedule.
#
#   Called automatically by the claude and agy wrappers on every invocation.
#
# ARGUMENTS
#   -a, --agents   Set up AGENTS/ repo + AGENTS.md / CLAUDE.md symlinks only
#   -p, --plugins  Set up AGENTS/ repo + plans/specs/devlogs dirs + docs/ symlinks only
#   -v, --verbose  Print all per-step output (default)
#   -q, --quiet    Print one summary line only if changes were made
#   -s, --silent   Suppress all output; errors only (standard UNIX convention)
#   -h, --help     Show this help message and exit
#
# EXIT STATUS
#   0  Setup completed successfully
#   1  Fatal error (git init failed, move failed, the AGENTS/ commit was
#      rejected, or an unresolved rebase blocked it)
#
# EXAMPLE
#   agents-init
#   agents-init --agents
#   agents-init --plugins
#   agents-init --quiet
function agents-init --description 'scaffold AGENTS/ sub-repo with agent spec files and plugin dirs'
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold)
    set -l c_flag (set_color yellow)
    set -l c_ok (set_color green)
    set -l c_warn (set_color yellow)
    set -l c_dim (set_color brblack)
    set -l c_err (set_color red)
    set -l c_reset (set_color normal)

    argparse h/help a/agents p/plugins v/verbose q/quiet s/silent -- $argv
    or return 1

    if set -q _flag_help
        echo "$c_head""Usage:$c_reset $c_cmd""agents-init$c_reset $c_flag""[-a] [-p] [-v] [-q] [-s] [-h | --help]$c_reset"
        echo
        echo "  Scaffold an AGENTS/ sub-repository for tracking agent specifications."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset      Show this help message"
        echo "  $c_flag-a$c_reset, $c_flag--agents$c_reset    Set up AGENTS.md / CLAUDE.md symlinks only"
        echo "  $c_flag-p$c_reset, $c_flag--plugins$c_reset   Set up plans/specs/devlogs dirs and docs/ symlinks only"
        echo "  $c_flag-v$c_reset, $c_flag--verbose$c_reset   Print all per-step output (default)"
        echo "  $c_flag-q$c_reset, $c_flag--quiet$c_reset     Print one summary line only if changes were made"
        echo "  $c_flag-s$c_reset, $c_flag--silent$c_reset    Suppress all output; only errors are printed"
        echo "  $c_dim(no flags)$c_reset      Run both --agents and --plugins setup"
        return 0
    end

    # No flags → run both modes
    set -l do_agents 0
    set -l do_plugins 0
    set -q _flag_agents; and set do_agents 1
    set -q _flag_plugins; and set do_plugins 1
    if test $do_agents -eq 0; and test $do_plugins -eq 0
        set do_agents 1
        set do_plugins 1
    end

    # Output verbosity: verbose (default), quiet (summary if changed), silent (errors only)
    set -l verbose 1
    set -l quiet 0
    if set -q _flag_silent
        set verbose 0
    else if set -q _flag_quiet
        set verbose 0
        set quiet 1
    end
    # --verbose is explicit default; no-op but accepted for completeness

    # Resolve target root: git root if available, otherwise cwd
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    test -z "$root"; and set root (pwd)

    set -l agents_dir "$root/AGENTS"
    set -l plugins_dir "$agents_dir/plugins"

    # Track whether any action was taken this run (drives quiet-mode summary)
    set -l changed 0

    #   ─────────────────────── Always: AGENTS/ sub-repo ───────────────────────
    set -l did_init 0

    if not test -d "$agents_dir"
        if not mkdir -p "$agents_dir"
            echo "$c_err""Error: could not create AGENTS/$c_reset" >&2
            return 1
        end
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Created AGENTS/$c_reset"
    end

    if not test -d "$agents_dir/.git"
        git -C "$agents_dir" init -q
        or begin
            echo "$c_err""Error: git init failed in AGENTS/$c_reset" >&2
            return 1
        end
        set changed 1
        set did_init 1
        test $verbose -eq 1; and echo "$c_ok→ Initialized git repo in AGENTS/$c_reset"
    end

    #   ─────────────── Always: version tracking (.version + hooks) ───────────────
    if not test -f "$agents_dir/.version"
        echo 1.0.0 >"$agents_dir/.version"
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Created AGENTS/.version (1.0.0)$c_reset"
    end

    set -l _tools (_agents_repo_install_tools "$agents_dir")
    if test -n "$_tools"
        set changed 1
        test $verbose -eq 1; and echo "$c_ok$_tools$c_reset"
    end

    set -l _hp (git -C "$agents_dir" config --local core.hooksPath 2>/dev/null)
    if test "$_hp" != .agents-tools/hooks
        git -C "$agents_dir" config --local core.hooksPath .agents-tools/hooks
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Set core.hooksPath → .agents-tools/hooks$c_reset"
    end

    #   ──────────────────────────── --agents mode ──────────────────────────────
    if test $do_agents -eq 1
        # Detect which root-level files are real (not symlinks)
        set -l has_agents 0
        set -l has_claude 0
        if test -f "$root/AGENTS.md"; and not test -L "$root/AGENTS.md"
            set has_agents 1
        end
        if test -f "$root/CLAUDE.md"; and not test -L "$root/CLAUDE.md"
            set has_claude 1
        end

        # ── Move real files into AGENTS/ ──────────────────────────────────────
        if test $has_agents -eq 1; and test $has_claude -eq 1
            # Both exist: preserve each as its own file in AGENTS/
            if not test -f "$agents_dir/AGENTS.md"
                if not mv "$root/AGENTS.md" "$agents_dir/AGENTS.md"
                    echo "$c_err""Error: could not move AGENTS.md → AGENTS/AGENTS.md$c_reset" >&2
                    return 1
                end
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Moved AGENTS.md → AGENTS/AGENTS.md$c_reset"
            end
            if not test -f "$agents_dir/CLAUDE.md"; and not test -L "$agents_dir/CLAUDE.md"
                if not mv "$root/CLAUDE.md" "$agents_dir/CLAUDE.md"
                    echo "$c_err""Error: could not move CLAUDE.md → AGENTS/CLAUDE.md$c_reset" >&2
                    return 1
                end
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Moved CLAUDE.md → AGENTS/CLAUDE.md$c_reset"
            end
        else if test $has_agents -eq 1
            if not test -f "$agents_dir/AGENTS.md"
                if not mv "$root/AGENTS.md" "$agents_dir/AGENTS.md"
                    echo "$c_err""Error: could not move AGENTS.md → AGENTS/AGENTS.md$c_reset" >&2
                    return 1
                end
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Moved AGENTS.md → AGENTS/AGENTS.md$c_reset"
            end
        else if test $has_claude -eq 1
            # Only CLAUDE.md: treat it as the agent spec
            if not test -f "$agents_dir/AGENTS.md"
                if not mv "$root/CLAUDE.md" "$agents_dir/AGENTS.md"
                    echo "$c_err""Error: could not move CLAUDE.md → AGENTS/AGENTS.md$c_reset" >&2
                    return 1
                end
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Moved CLAUDE.md → AGENTS/AGENTS.md$c_reset"
            end
        else
            # Neither exists: create AGENTS/AGENTS.md with the agent directive
            if not test -f "$agents_dir/AGENTS.md"
                printf '%s\n' \
                    '# AGENTS.md' \
                    '' \
                    '> ⚠️ **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' \
                    '> You may be reading this file via a symlink (`CLAUDE.md` or `AGENTS.md`) in' \
                    '> the root of the project. Your environment'\''s file-editing tools cannot write' \
                    '> through symlinks and will throw an error.' \
                    '>' \
                    '> **DO NOT** attempt to write to or edit `CLAUDE.md` or `AGENTS.md` in the' \
                    '> project root. If you need to update these instructions, you **MUST write' \
                    '> directly to `AGENTS/AGENTS.md`**.' >"$agents_dir/AGENTS.md"
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Created AGENTS/AGENTS.md with agent directive$c_reset"
            end
        end

        # ── Ensure AGENTS/CLAUDE.md exists ────────────────────────────────────
        # When both files existed, AGENTS/CLAUDE.md is already a real file.
        # Otherwise, create it as a symlink → AGENTS.md (within AGENTS/).
        if not test -f "$agents_dir/CLAUDE.md"; and not test -L "$agents_dir/CLAUDE.md"
            if not ln -s AGENTS.md "$agents_dir/CLAUDE.md"
                echo "$c_err""Error: could not create AGENTS/CLAUDE.md symlink$c_reset" >&2
                return 1
            end
            set changed 1
            test $verbose -eq 1; and echo "$c_ok→ Linked AGENTS/CLAUDE.md → AGENTS/AGENTS.md$c_reset"
        end

        # Root symlinks point at files, not directories, so they cannot use
        # _agents_repo_ensure_symlink (which is directory-only by design).
        for pair in "AGENTS.md:AGENTS/AGENTS.md" "CLAUDE.md:AGENTS/CLAUDE.md"
            set -l name (string split -f1 ':' -- $pair)
            set -l want (string split -f2 ':' -- $pair)
            set -l need 0
            if not test -L "$root/$name"
                set need 1
            else if test (readlink "$root/$name") != "$want"
                rm -f "$root/$name"
                set need 1
            end
            if test $need -eq 1
                if not ln -s "$want" "$root/$name"
                    echo "$c_err""Error: could not create $name symlink$c_reset" >&2
                    return 1
                end
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Linked $name → $want$c_reset"
            end
        end

        # ── .gitignore ────────────────────────────────────────────────────────
        set -l _gi (_agents_init_ensure_gitignore "$root" "agents-init --agents" "AGENTS/" "/AGENTS.md" "/CLAUDE.md")
        if test -n "$_gi"
            set changed 1
            test $verbose -eq 1; and echo $_gi
        end
    end

    #   ─────────────────────────── --plugins mode ──────────────────────────────
    if test $do_plugins -eq 1
        set -l docs_dir "$root/docs"

        if not test -d "$docs_dir"
            if not mkdir -p "$docs_dir"
                echo "$c_err""Error: could not create docs/$c_reset" >&2
                return 1
            end
            set changed 1
            test $verbose -eq 1; and echo "$c_ok→ Created docs/$c_reset"
        end

        # Consolidate plans/ and specs/ directly under AGENTS/ (no plugins/ layer).
        # Real source dirs from any known layout are merged into the canonical
        # AGENTS/<tgt> and removed: docs/<tgt>, docs/superpowers/<tgt>,
        # AGENTS/plugins/<tgt>, AGENTS/plugins/superpowers/<tgt> (legacy).
        # Symlinks: docs/superpowers/<tgt> always (superpowers skills expect it);
        # docs/<tgt> only when it had existed as a real directory.
        for tgt in plans specs
            set -l canonical "$agents_dir/$tgt"

            # Remember whether docs/<tgt> was a real dir (drives its symlink below)
            set -l docs_tgt_was_real 0
            if test -d "$docs_dir/$tgt"; and not test -L "$docs_dir/$tgt"
                set docs_tgt_was_real 1
            end

            test -d "$canonical"; or mkdir -p "$canonical"

            # Candidate real source dirs to merge into the canonical dir
            set -l srcs "$docs_dir/$tgt" "$plugins_dir/$tgt" "$plugins_dir/superpowers/$tgt"
            # Only follow docs/superpowers/<tgt> when docs/superpowers is a real
            # dir; if it is a legacy symlink, its target is already covered by the
            # AGENTS/plugins/superpowers/<tgt> source above.
            if not test -L "$docs_dir/superpowers"
                set -a srcs "$docs_dir/superpowers/$tgt"
            end

            for src in $srcs
                if test -d "$src"; and not test -L "$src"
                    set -l rel (string replace "$root/" "" "$src")
                    set -l contents (command ls -A "$src" 2>/dev/null)
                    if test (count $contents) -gt 0
                        if not command cp -rn "$src/." "$canonical/"
                            echo "$c_err""Error: could not merge $rel → AGENTS/$tgt$c_reset" >&2
                            return 1
                        end
                    end
                    if not rm -rf "$src"
                        echo "$c_err""Error: could not remove $rel after merge$c_reset" >&2
                        return 1
                    end
                    set changed 1
                    test $verbose -eq 1; and echo "$c_ok→ Merged $rel → AGENTS/$tgt$c_reset"
                end
            end

            test -f "$canonical/.gitkeep"; or touch "$canonical/.gitkeep"

            # docs/<tgt> symlink: only recreated when it had been a real directory
            set -l docs_link "$docs_dir/$tgt"
            if test $docs_tgt_was_real -eq 1
                if not test -L "$docs_link"
                    if not ln -s "../AGENTS/$tgt" "$docs_link"
                        echo "$c_err""Error: could not create docs/$tgt symlink$c_reset" >&2
                        return 1
                    end
                    set changed 1
                    test $verbose -eq 1; and echo "$c_ok→ Linked docs/$tgt → AGENTS/$tgt$c_reset"
                end
            else if test -L "$docs_link"; and test (readlink "$docs_link") != "../AGENTS/$tgt"
                # Stale legacy symlink (pointed into AGENTS/plugins) → drop it
                rm -f "$docs_link"
                set changed 1
                test $verbose -eq 1; and echo "$c_warn→ Removed stale docs/$tgt symlink$c_reset"
            end
        end

        # docs/superpowers/ must be a real dir holding the plans/ + specs/ symlinks.
        # Replace any legacy docs/superpowers symlink (content merged above).
        if test -L "$docs_dir/superpowers"
            rm -f "$docs_dir/superpowers"
            set changed 1
            test $verbose -eq 1; and echo "$c_warn→ Removed legacy docs/superpowers symlink$c_reset"
        end
        if not test -d "$docs_dir/superpowers"
            if not mkdir -p "$docs_dir/superpowers"
                echo "$c_err""Error: could not create docs/superpowers/$c_reset" >&2
                return 1
            end
        end

        # docs/superpowers/<tgt> symlinks — always present (superpowers default)
        for tgt in plans specs
            set -l sp_link "$docs_dir/superpowers/$tgt"
            if not test -L "$sp_link"
                if not ln -s "../../AGENTS/$tgt" "$sp_link"
                    echo "$c_err""Error: could not create docs/superpowers/$tgt symlink$c_reset" >&2
                    return 1
                end
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Linked docs/superpowers/$tgt → AGENTS/$tgt$c_reset"
            else if test (readlink "$sp_link") != "../../AGENTS/$tgt"
                rm -f "$sp_link"
                ln -s "../../AGENTS/$tgt" "$sp_link"
                set changed 1
                test $verbose -eq 1; and echo "$c_ok→ Relinked docs/superpowers/$tgt → AGENTS/$tgt$c_reset"
            end
        end

        # Drop the now-empty legacy AGENTS/plugins/ layer entirely
        if test -d "$plugins_dir"
            rm -rf "$plugins_dir"
            set changed 1
            test $verbose -eq 1; and echo "$c_warn→ Removed legacy AGENTS/plugins/$c_reset"
        end

        # ── AGENTS/devlogs (standard location for agent dev logs) ─────────────
        set -l devlogs_dir "$agents_dir/devlogs"
        set -l docs_devlogs "$docs_dir/devlogs"

        if test -d "$docs_devlogs"; and not test -L "$docs_devlogs"
            # Migrate an existing docs/devlogs into AGENTS/devlogs, then symlink
            test -d "$devlogs_dir"; or mkdir -p "$devlogs_dir"
            set -l contents (command ls -A "$docs_devlogs" 2>/dev/null)
            if test (count $contents) -gt 0
                if not command cp -rn "$docs_devlogs/." "$devlogs_dir/"
                    echo "$c_err""Error: could not copy docs/devlogs → AGENTS/devlogs$c_reset" >&2
                    return 1
                end
            end
            if not rm -rf "$docs_devlogs"
                echo "$c_err""Error: could not remove docs/devlogs after copy$c_reset" >&2
                return 1
            end
            if not ln -s "../AGENTS/devlogs" "$docs_devlogs"
                echo "$c_err""Error: could not create docs/devlogs symlink$c_reset" >&2
                return 1
            end
            set changed 1
            test $verbose -eq 1; and echo "$c_ok→ Moved docs/devlogs → AGENTS/devlogs$c_reset"
        else if not test -d "$devlogs_dir"
            if not mkdir -p "$devlogs_dir"
                echo "$c_err""Error: could not create AGENTS/devlogs$c_reset" >&2
                return 1
            end
            set changed 1
            test $verbose -eq 1; and echo "$c_ok→ Created AGENTS/devlogs/$c_reset"
        end
        test -f "$devlogs_dir/.gitkeep"; or touch "$devlogs_dir/.gitkeep"

        set -l _gi (_agents_init_ensure_gitignore "$root" "agents-init --plugins" "docs/superpowers" "docs/plans" "docs/specs" "docs/devlogs")
        if test -n "$_gi"
            set changed 1
            test $verbose -eq 1; and echo $_gi
        end
    end

    #   ──────────────────────── Auto-commit AGENTS/ ────────────────────────────
    # Purely local: no fetch, no push. This function runs synchronously on
    # every agent launch, and a network round trip there blocks the launch
    # for as long as an unreachable remote takes to time out. Committing
    # never needed one -- see _agents_repo_sync.
    #
    # Every way the commit can fail is an arm of its own. A sync that did
    # not commit means agent-made edits were not captured, so it is a
    # failure rather than a line to walk past -- and the missing `-ne 0`
    # arm was not a cosmetic gap: fish resolves a branchless `if` to 0, so
    # a hook-rejected commit fell straight through to a reported success.
    set -l msg "chore: sync AGENTS repository"
    test $did_init -eq 1; and set msg "chore: initialize AGENTS repository"
    set -l sync_out (_agents_repo_sync "$agents_dir" "$msg")
    set -l sync_rc $status
    set -l failed 0
    if test $sync_rc -eq 2
        echo "$c_warn→ AGENTS/ has an unresolved rebase; nothing committed$c_reset" >&2
        set failed 1
    else if test $sync_rc -ne 0
        echo "$c_err""Error: the AGENTS/ commit failed; nothing recorded$c_reset" >&2
        set failed 1
    else if test -n "$sync_out"
        set changed 1
        test $verbose -eq 1; and echo "$c_ok$sync_out$c_reset"
    end

    # Quiet summary: one line at the end, only if something actually changed
    if test $quiet -eq 1; and test $changed -eq 1
        if test $did_init -eq 1
            echo "$c_ok→ Initialized AGENTS scaffolding$c_reset"
        else
            echo "$c_ok→ Synced AGENTS scaffolding$c_reset"
        end
    end

    # Explicit, because the branchless `if` above resolves to 0 and would
    # otherwise be this function's exit status.
    test $failed -eq 0
end
