# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# DEPENDENCIES
#   _agents_init_find, _agents_init_sync_instructions, _agents_init_sync_public, _agents_init_migrate_public, _agents_repo_install_tools, _agents_repo_sync, _agents_init_ensure_gitignore
#
# CLASSIFICATION
#   self-limiting(rm,mkdir,grep), bypasses-shadow(mv), manual-section(16-agent-tooling)
#
# SYNOPSIS
#   agents-init [-a | --agents] [-p | --plugins] [-e | --enable]
#               [--public | --private]
#               [-v | --verbose] [-q | --quiet] [-s | --silent] [-h | --help]
#
# DESCRIPTION
#   Scaffolds an AGENTS/ sub-repository inside a project directory. Creates
#   a self-contained git repo for agent specifications, moves any existing
#   agent-related files into it, and replaces them with symlinks so the
#   outer project never tracks agent files directly. This applies at the
#   project root and, automatically, to any subdirectory that carries its
#   own scoped AGENTS.md or CLAUDE.md -- discovered by scanning the tree,
#   not a hardcoded list. The scan prunes dot-directories (.git/, .claude/,
#   ...), nested repos, AGENTS/ itself, node_modules/, and generated-output
#   directories (build/, dist/, out/, target/).
#
#   A real instruction file that the project deliberately tracks -- in
#   git's index, in a project whose .gitignore is non-empty -- is left
#   exactly where it is, with a warning, rather than moved into AGENTS/ and
#   replaced by a symlink. See _agents_init_path_is_protected.
#
#   Scaffolding runs only inside a git repository, or in a directory that
#   already has an AGENTS.md, CLAUDE.md, or AGENTS/. Elsewhere it is a
#   no-op, so running an agent CLI in an arbitrary directory does not
#   create a repository there.
#
#   A project marked disabled is skipped entirely. agents-cleanup sets the
#   per-clone git config key agents-init.disabled; a .agents-disabled file
#   in the project root, which a team may commit, has the same effect.
#   Either one turns every wrapper launch into a silent no-op there.
#   --enable clears the git key and scaffolds; the file has to be deleted
#   by hand, because it is a decision shared with every clone.
#
#   Two modes, recorded in AGENTS/.mode. In both, each real file lives in
#   the repository whose visibility matches it, and the other side holds a
#   symlink:
#
#     public (default for a new project inside git)
#       <root>/AGENTS.md                 real, tracked by the project
#       <root>/AGENTS.local.md           → AGENTS/AGENTS.local.md (gitignored)
#       AGENTS/AGENTS.local.md           private instructions (real file)
#       AGENTS/AGENTS.md                 → ../AGENTS.md
#     private (every project scaffolded before modes existed)
#       the layout below, unchanged.
#
#   The public starter AGENTS.md points agents at AGENTS.local.md, both as
#   an @ import (Claude Code expands it) and as a plain sentence (agents
#   that do not expand imports still follow it). A real public AGENTS.md is
#   never moved or rewritten. A project with no AGENTS/.mode is private.
#   --public on a private project migrates it: each private AGENTS.md is
#   renamed to AGENTS.local.md inside AGENTS/ (history kept) and replaced in
#   the project by a public starter, so nothing private is published.
#   Nothing is committed in the project; review and commit it yourself.
#   --private on a public project is refused: what was published is already
#   in history. Wrapper launches pass no mode flag and never change modes.
#
#   File layout after setup (private mode):
#     AGENTS/AGENTS.md          canonical root agent spec (real file)
#     AGENTS/<subdir>/AGENTS.md canonical spec for any subdir with its own
#                               scoped instructions (real file, discovered
#                               automatically -- see above)
#     <root>/AGENTS.md          → AGENTS/AGENTS.md
#     <root>/<subdir>/AGENTS.md → AGENTS/<subdir>/AGENTS.md
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
#   No CLAUDE.md survives anywhere in a managed tree: claude-code reads
#   AGENTS.md natively when CLAUDE.md is absent, so CLAUDE.md exists here
#   purely as a retirement target -- any found (root or subdirectory, real
#   file or leftover symlink) is folded into the AGENTS.md-only shape
#   above by _agents_init_sync_instructions.
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
#   -a, --agents   Set up AGENTS/ repo + AGENTS.md symlinks (root and every
#                  discovered subdirectory) only
#   -p, --plugins  Set up AGENTS/ repo + plans/specs/devlogs dirs + docs/ symlinks only
#   -e, --enable   Clear the git key agents-cleanup set, then scaffold as
#                  normal (refused while .agents-disabled exists)
#   --public       New project: scaffold public mode (the default inside git).
#                  Private project: migrate it to public mode.
#   --private      New project: scaffold private mode. Refused on a public
#                  project.
#   -v, --verbose  Print all per-step output (default)
#   -q, --quiet    Print one summary line only if changes were made
#   -s, --silent   Suppress all output; errors only (standard UNIX convention)
#   -h, --help     Show this help message and exit
#
# EXIT STATUS
#   0  Setup completed successfully
#   1  Fatal error (git init failed, move failed, the AGENTS/ commit was
#      rejected, or an unresolved rebase blocked it), --enable refused
#      because .agents-disabled exists, a migration precondition failed,
#      --private given for a public project, or both mode flags given
#
# EXAMPLE
#   agents-init
#   agents-init --agents
#   agents-init --plugins
#   agents-init --quiet
#   agents-init --public
#
# NOTES
#   This header covers usage only. The full concept/behavior/purpose
#   write-up -- the AGENTS.md convention, the AGENTS/ sub-repository, the
#   discovery and safety model, and a complete scenario-by-scenario
#   reference table -- lives in its own manual section:
#   docs/manual/16-agent-tooling.md. Update that section in the same
#   change whenever this function's behavior changes; see "Dedicated
#   manual sections for complex subsystems" in CONTRIBUTING.md.
function agents-init --description 'scaffold AGENTS/ sub-repo with agent spec files and plugin dirs'
    __fish_palette

    argparse h/help a/agents p/plugins e/enable public private v/verbose q/quiet s/silent -- $argv
    or return 1

    if set -q _flag_help
        echo "$c_head""Usage:$c_reset $c_cmd""agents-init$c_reset $c_flag""[-a] [-p] [-e] [--public | --private] [-v] [-q] [-s] [-h | --help]$c_reset"
        echo
        echo "  Scaffold an AGENTS/ sub-repository for tracking agent specifications."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset      Show this help message"
        echo "  $c_flag-a$c_reset, $c_flag--agents$c_reset    Set up AGENTS.md symlinks only"
        echo "  $c_flag-p$c_reset, $c_flag--plugins$c_reset   Set up plans/specs/devlogs dirs and docs/ symlinks only"
        echo "  $c_flag-e$c_reset, $c_flag--enable$c_reset    Re-enable a project agents-cleanup disabled"
        echo "      $c_flag--public$c_reset    New project: public AGENTS.md (default); private project: migrate"
        echo "      $c_flag--private$c_reset   New project: keep AGENTS.md private in AGENTS/"
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

    # Only scaffold inside a git repository, or where an agent file already
    # exists. Falling back to (pwd) meant `claude --version` in any
    # directory created an AGENTS/ repo, two root symlinks, and a docs/
    # tree there.
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    set -l in_git 1
    if test -z "$root"
        set in_git 0
        if test -e (pwd)/AGENTS.md -o -e (pwd)/CLAUDE.md -o -d (pwd)/AGENTS
            set root (pwd)
        else
            test $verbose -eq 1
            and echo "$c_dim→ Not a git repository; skipping AGENTS/ scaffolding$c_reset"
            return 0
        end
    end

    #   ─────────────────────────── Opt-out marker ───────────────────────────
    # agents-cleanup marks a project it has undone so launches stop
    # re-scaffolding it: a per-clone git config key, or a .agents-disabled
    # file a team may commit. The file is a shared decision, so --enable
    # refuses rather than silently overriding it.
    set -l marker_file "$root/.agents-disabled"
    set -l key_set 0
    if test $in_git -eq 1
        set -l key (git -C "$root" config --type=bool --get agents-init.disabled 2>/dev/null)
        test "$key" = true; and set key_set 1
    end
    if set -q _flag_enable
        if test -e "$marker_file"
            echo "$c_err""Error: .agents-disabled disables agents-init for every clone; delete it (and commit the deletion) to re-enable$c_reset" >&2
            return 1
        end
        if test $in_git -eq 1; and git -C "$root" config --local --get agents-init.disabled >/dev/null 2>&1
            git -C "$root" config --local --unset agents-init.disabled
            test $verbose -eq 1; and echo "$c_ok→ Re-enabled agents-init (unset git config agents-init.disabled)$c_reset"
        end
    else if test -e "$marker_file"
        test $verbose -eq 1; and echo "$c_dim→ agents-init is disabled here by .agents-disabled; delete that file to re-enable$c_reset"
        return 0
    else if test $key_set -eq 1
        test $verbose -eq 1; and echo "$c_dim→ agents-init is disabled here (git config agents-init.disabled); run agents-init --enable to re-enable$c_reset"
        return 0
    end

    set -l agents_dir "$root/AGENTS"
    set -l plugins_dir "$agents_dir/plugins"

    #   ──────────────────────────────── Mode ────────────────────────────────
    # AGENTS/.mode records public or private. A project scaffolded before
    # modes existed has none and stays private until migrated explicitly; a
    # new project inside git defaults to public. Outside git there is
    # nothing to publish, so a new project there is private.
    if set -q _flag_public; and set -q _flag_private
        echo "$c_err""Error: --public and --private are mutually exclusive$c_reset" >&2
        return 1
    end
    set -l fresh 0
    test -d "$agents_dir"; or set fresh 1
    set -l mode_file "$agents_dir/.mode"
    set -l mode private
    if test -f "$mode_file"
        set mode (string trim -- (command head -n1 "$mode_file"))
        if not contains -- "$mode" public private
            echo "$c_warn""→ AGENTS/.mode holds '$mode', not public or private; treating as private$c_reset" >&2
            set mode private
        end
    else if test $fresh -eq 1; and test $in_git -eq 1
        set mode public
    end
    set -l migrate 0
    if set -q _flag_private
        if test "$mode" = public; and test $fresh -eq 0
            echo "$c_err""Error: this project is in public mode; its AGENTS.md is meant to be published. Going back to private is done by hand -- see docs/manual/16-agent-tooling.md$c_reset" >&2
            return 1
        end
        set mode private
    else if set -q _flag_public
        if test $in_git -eq 0
            echo "$c_err""Error: public mode needs a git repository$c_reset" >&2
            return 1
        end
        test $fresh -eq 0; and test "$mode" = private; and set migrate 1
        set mode public
    end

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

    # A new project records its mode; a migration records it last, itself.
    if test $fresh -eq 1; and not test -f "$mode_file"
        printf '%s\n' $mode >"$mode_file"
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Created AGENTS/.mode ($mode)$c_reset"
    end

    set -l _hp (git -C "$agents_dir" config --local core.hooksPath 2>/dev/null)
    if test "$_hp" != .agents-tools/hooks
        git -C "$agents_dir" config --local core.hooksPath .agents-tools/hooks
        set changed 1
        test $verbose -eq 1; and echo "$c_ok→ Set core.hooksPath → .agents-tools/hooks$c_reset"
    end

    #   ───────────────────────── Migration to public ─────────────────────────
    # Commit what is pending first, so the migration commit holds only the
    # migration, then convert. Everything the migration changes in the
    # project itself is left uncommitted for the user to review.
    if test $migrate -eq 1
        set -l pre_out (_agents_repo_sync "$agents_dir" "chore: sync AGENTS repository" 2>/dev/null)
        if test $status -ne 0
            echo "$c_err""Error: could not commit pending AGENTS/ changes before migrating; nothing migrated$c_reset" >&2
            return 1
        end
        set -l mig_out (_agents_init_migrate_public "$root" "$agents_dir")
        set -l mig_rc $status
        if test $verbose -eq 1
            for line in $mig_out
                echo "$c_ok$line$c_reset"
            end
        end
        if test $mig_rc -ne 0
            echo "$c_err""Error: migration to public mode stopped; fix the error above and re-run agents-init --public$c_reset" >&2
            return 1
        end
        set changed 1
    end

    #   ──────────────────────────── --agents mode ──────────────────────────────
    if test $do_agents -eq 1
        # Discover every directory carrying agent instructions -- root
        # included, subdirectories found automatically rather than by a
        # hardcoded list. A real file, an already-migrated symlink, or a
        # leftover inverted-mirror survivor all match, so one pass covers
        # fresh, migrated, and legacy state alike.
        #
        # Discovery stays inside this project: a non-git root (a lone
        # agent file in, say, ~) syncs only itself -- walking it would
        # reach into every unrelated tree below. In a git root the walk
        # uses the shared prune set; see _agents_init_find.
        set -l found
        if test $in_git -eq 1
            set found (_agents_init_find "$root" \( -name AGENTS.md -o -name CLAUDE.md -o -name AGENTS.local.md \) -print)
        end
        # Public mode: a private file the user created in the mirror marks
        # its directory too, so it gets linked into the project.
        if test "$mode" = public
            for f in (find "$agents_dir" -name .git -prune -o -name AGENTS.local.md -print)
                set -a found (string replace -- "$agents_dir" "$root" "$f")
            end
        end
        set -l rels "."
        for f in $found
            set -l d (path dirname "$f")
            set -l rel (string replace "$root/" "" "$d")
            test "$rel" = "$d"; and set rel "."
            contains -- "$rel" $rels; or set -a rels "$rel"
        end

        set -l sync_fn _agents_init_sync_instructions
        test "$mode" = public; and set sync_fn _agents_init_sync_public
        for rel in $rels
            set -l out ($sync_fn "$root" "$agents_dir" "$rel")
            set -l rc $status
            if test $rc -ne 0
                echo "$c_err""Error: could not sync AGENTS.md for $rel$c_reset" >&2
                return 1
            end
            if test -n "$out"
                set changed 1
                if test $verbose -eq 1
                    for line in $out
                        echo "$c_ok$line$c_reset"
                    end
                end
            end
        end

        # ── Migrate stale anchored gitignore lines ──────────────────────────────
        # A project scaffolded by the old agents-init already has anchored
        # /AGENTS.md and/or /CLAUDE.md lines in .gitignore. git check-ignore
        # sees those as covering the literal path "AGENTS.md", so the new
        # unanchored pattern below would be judged already-covered and never
        # added -- leaving any newly discovered subdirectory AGENTS.md with no
        # gitignore coverage at all. Strip the stale exact lines first so the
        # unanchored pattern always gets a chance to be added. No-op when
        # neither stale line is present.
        set -l gitignore "$root/.gitignore"
        if test -f "$gitignore"
            if grep -qxF "/AGENTS.md" "$gitignore"
                sed -i '/^\/AGENTS\.md$/d' "$gitignore"
                set changed 1
                test $verbose -eq 1; and echo "$c_warn→ Removed stale /AGENTS.md line from .gitignore$c_reset"
            end
            if grep -qxF "/CLAUDE.md" "$gitignore"
                sed -i '/^\/CLAUDE\.md$/d' "$gitignore"
                set changed 1
                test $verbose -eq 1; and echo "$c_warn→ Removed stale /CLAUDE.md line from .gitignore$c_reset"
            end
        end

        # ── .gitignore ────────────────────────────────────────────────────────
        # Unanchored: matches AGENTS.md at every depth, so a newly
        # discovered subdirectory needs no additional gitignore entry.
        # CLAUDE.md is dropped entirely -- nothing creates one anymore.
        # Public mode ignores the private AGENTS.local.md links, never the
        # public AGENTS.md.
        set -l _inst AGENTS.md
        test "$mode" = public; and set _inst AGENTS.local.md
        set -l _gi (_agents_init_ensure_gitignore "$root" "agents-init --agents" "AGENTS/" $_inst)
        if test -n "$_gi"
            set changed 1
            test $verbose -eq 1; and echo $_gi
        end

        if test "$mode" = public
            # A rule outside agents-init's blocks can still hide the public
            # file. Never edited here: those lines are the user's.
            if test $migrate -eq 1; or test $verbose -eq 1
                set -l why (git -C "$root" check-ignore -v --no-index AGENTS.md 2>/dev/null)
                if test -n "$why"
                    echo "$c_warn→ AGENTS.md is still ignored by a rule outside agents-init's blocks, so it cannot be committed: $why$c_reset" >&2
                end
            end
            # A private file nothing points at is never read. Hint only:
            # a public AGENTS.md is the project's, and is not edited here.
            if test $verbose -eq 1
                for rel in $rels
                    set -l d "$root"
                    test "$rel" != "."; and set d "$root/$rel"
                    if test -e "$d/AGENTS.local.md"; and test -f "$d/AGENTS.md"; and not test -L "$d/AGENTS.md"
                        if not grep -qF '@AGENTS.local.md' "$d/AGENTS.md"
                            set -l shown AGENTS.md
                            test "$rel" != "."; and set shown "$rel/AGENTS.md"
                            echo "$c_dim→ $shown does not reference @AGENTS.local.md, so agents will not read the private file; add the line from: _agents_init_stub --public$c_reset"
                        end
                    end
                end
            end
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
                        if not command cp -r --update=none "$src/." "$canonical/"
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
                if not command cp -r --update=none "$docs_devlogs/." "$devlogs_dir/"
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
    test $migrate -eq 1; and set msg "chore: migrate AGENTS to public mode"
    # 2>/dev/null: a command substitution's stderr does not inherit a
    # caller-scoped redirect on this call (fish quirk), so _agents_repo_sync's
    # own error message leaks past --silent regardless; it is redundant with
    # the $sync_rc-driven echoes just below anyway.
    set -l sync_out (_agents_repo_sync "$agents_dir" "$msg" 2>/dev/null)
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

    if test $migrate -eq 1; and test $failed -eq 0; and not set -q _flag_silent
        echo "$c_head→ Migrated to public mode.$c_reset Nothing is committed in the project. Review the new public AGENTS.md file(s) and .gitignore, move anything worth publishing out of AGENTS.local.md, then commit."
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
