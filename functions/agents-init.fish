# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   agents-init [--agents] [--plugins] [-q | --quiet] [-s | --silent] [-h | --help]
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
#     docs/<plug>               → ../AGENTS/plugins/<plug>
#
#   With no flags, runs both --agents and --plugins setup. At the end of
#   every invocation, commits any uncommitted changes in the AGENTS/ sub-repo
#   so that agent-made edits are captured automatically.
#
# ARGUMENTS
#   --agents   Set up AGENTS/ repo + AGENTS.md / CLAUDE.md symlinks only
#   --plugins  Set up AGENTS/ repo + plugins dirs + docs/ symlinks only
#   -q, --quiet  Print only a start/done banner; suppress per-step output
#   -s, --silent Suppress all output; errors only (standard UNIX convention)
#   -h, --help Show this help message and exit
#
# RETURNS
#   0  Setup completed successfully
#   1  Fatal error (git init failed, move failed, etc.)
#
# EXAMPLE
#   agents-init
#   agents-init --agents
#   agents-init --plugins
#   agents-init --quiet
function agents-init --description 'scaffold AGENTS/ sub-repo with agent spec files and plugin dirs'
    set -l c_head  (set_color --bold cyan)
    set -l c_cmd   (set_color --bold white)
    set -l c_flag  (set_color yellow)
    set -l c_ok    (set_color green)
    set -l c_warn  (set_color yellow)
    set -l c_dim   (set_color brblack)
    set -l c_err   (set_color red)
    set -l c_reset (set_color normal)

    argparse 'h/help' 'agents' 'plugins' 'q/quiet' 's/silent' -- $argv
    or return 1

    if set -q _flag_help
        echo "$c_head""Usage:$c_reset $c_cmd""agents-init$c_reset $c_flag""[--agents] [--plugins] [-q] [-s] [-h | --help]$c_reset"
        echo
        echo "  Scaffold an AGENTS/ sub-repository for tracking agent specifications."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset     Show this help message"
        echo "  $c_flag--agents$c_reset        Set up AGENTS.md / CLAUDE.md symlinks only"
        echo "  $c_flag--plugins$c_reset       Set up plugins dirs and docs/ symlinks only"
        echo "  $c_flag-q$c_reset, $c_flag--quiet$c_reset    Print only a start/done banner; suppress per-step output"
        echo "  $c_flag-s$c_reset, $c_flag--silent$c_reset   Suppress all output; only errors are printed"
        echo "  $c_dim(no flags)$c_reset       Run both --agents and --plugins setup"
        return 0
    end

    # No flags → run both modes
    set -l do_agents 0
    set -l do_plugins 0
    set -q _flag_agents;  and set do_agents 1
    set -q _flag_plugins; and set do_plugins 1
    if test $do_agents -eq 0; and test $do_plugins -eq 0
        set do_agents 1
        set do_plugins 1
    end

    # Output verbosity: verbose (default), quiet (banner only), silent (errors only)
    set -l verbose 1
    set -l quiet 0
    if set -q _flag_silent
        set verbose 0
    else if set -q _flag_quiet
        set verbose 0
        set quiet 1
    end

    # Resolve target root: git root if available, otherwise cwd
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    test -z "$root"; and set root (pwd)

    set -l agents_dir  "$root/AGENTS"
    set -l plugins_dir "$agents_dir/plugins"

    test $quiet -eq 1; and echo "$c_head→ Initializing AGENTS scaffolding…$c_reset"

    #   ─────────────────────── Always: AGENTS/ sub-repo ───────────────────────
    set -l did_init 0

    if not test -d "$agents_dir"
        if not mkdir -p "$agents_dir"
            echo "$c_err""Error: could not create AGENTS/$c_reset" >&2
            return 1
        end
        test $verbose -eq 1; and echo "$c_ok→ Created AGENTS/$c_reset"
    end

    if not test -d "$agents_dir/.git"
        git -C "$agents_dir" init -q
        or begin
            echo "$c_err""Error: git init failed in AGENTS/$c_reset" >&2
            return 1
        end
        test $verbose -eq 1; and echo "$c_ok→ Initialized git repo in AGENTS/$c_reset"
        set did_init 1
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
                test $verbose -eq 1; and echo "$c_ok→ Moved AGENTS.md → AGENTS/AGENTS.md$c_reset"
            end
            if not test -f "$agents_dir/CLAUDE.md"; and not test -L "$agents_dir/CLAUDE.md"
                if not mv "$root/CLAUDE.md" "$agents_dir/CLAUDE.md"
                    echo "$c_err""Error: could not move CLAUDE.md → AGENTS/CLAUDE.md$c_reset" >&2
                    return 1
                end
                test $verbose -eq 1; and echo "$c_ok→ Moved CLAUDE.md → AGENTS/CLAUDE.md$c_reset"
            end
        else if test $has_agents -eq 1
            if not test -f "$agents_dir/AGENTS.md"
                if not mv "$root/AGENTS.md" "$agents_dir/AGENTS.md"
                    echo "$c_err""Error: could not move AGENTS.md → AGENTS/AGENTS.md$c_reset" >&2
                    return 1
                end
                test $verbose -eq 1; and echo "$c_ok→ Moved AGENTS.md → AGENTS/AGENTS.md$c_reset"
            end
        else if test $has_claude -eq 1
            # Only CLAUDE.md: treat it as the agent spec
            if not test -f "$agents_dir/AGENTS.md"
                if not mv "$root/CLAUDE.md" "$agents_dir/AGENTS.md"
                    echo "$c_err""Error: could not move CLAUDE.md → AGENTS/AGENTS.md$c_reset" >&2
                    return 1
                end
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
                    '> directly to `AGENTS/AGENTS.md`**.' \
                    > "$agents_dir/AGENTS.md"
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
            test $verbose -eq 1; and echo "$c_ok→ Linked AGENTS/CLAUDE.md → AGENTS/AGENTS.md$c_reset"
        end

        # ── Root symlink: AGENTS.md → AGENTS/AGENTS.md ───────────────────────
        set -l _need_link 0
        if not test -L "$root/AGENTS.md"
            set _need_link 1
        else if test (readlink "$root/AGENTS.md") != AGENTS/AGENTS.md
            rm -f "$root/AGENTS.md"
            set _need_link 1
        end
        if test $_need_link -eq 1
            if not ln -s AGENTS/AGENTS.md "$root/AGENTS.md"
                echo "$c_err""Error: could not create AGENTS.md symlink$c_reset" >&2
                return 1
            end
            test $verbose -eq 1; and echo "$c_ok→ Linked AGENTS.md → AGENTS/AGENTS.md$c_reset"
        end

        # ── Root symlink: CLAUDE.md → AGENTS/CLAUDE.md ───────────────────────
        set -l _need_link 0
        if not test -L "$root/CLAUDE.md"
            set _need_link 1
        else if test (readlink "$root/CLAUDE.md") != AGENTS/CLAUDE.md
            rm -f "$root/CLAUDE.md"
            set _need_link 1
        end
        if test $_need_link -eq 1
            if not ln -s AGENTS/CLAUDE.md "$root/CLAUDE.md"
                echo "$c_err""Error: could not create CLAUDE.md symlink$c_reset" >&2
                return 1
            end
            test $verbose -eq 1; and echo "$c_ok→ Linked CLAUDE.md → AGENTS/CLAUDE.md$c_reset"
        end

        # ── .gitignore ────────────────────────────────────────────────────────
        if test $verbose -eq 1
            _agents_init_ensure_gitignore "$root" "agents-init --agents" "AGENTS/" "/AGENTS.md" "/CLAUDE.md"
        else
            _agents_init_ensure_gitignore "$root" "agents-init --agents" "AGENTS/" "/AGENTS.md" "/CLAUDE.md" >/dev/null
        end
    end

    #   ─────────────────────────── --plugins mode ──────────────────────────────
    if test $do_plugins -eq 1
        # Ensure AGENTS/plugins/ dirs exist with .gitkeep
        for dir in "$plugins_dir" "$plugins_dir/superpowers" "$plugins_dir/plans" "$plugins_dir/specs"
            if not test -d "$dir"
                if not mkdir -p "$dir"
                    echo "$c_err""Error: could not create "(string replace "$root/" "" "$dir")"/$c_reset" >&2
                    return 1
                end
                test $verbose -eq 1; and echo "$c_ok→ Created "(string replace "$root/" "" "$dir")"/$c_reset"
            end
            test -f "$dir/.gitkeep"; or touch "$dir/.gitkeep"
        end

        set -l docs_dir "$root/docs"

        if not test -d "$docs_dir"
            if not mkdir -p "$docs_dir"
                echo "$c_err""Error: could not create docs/$c_reset" >&2
                return 1
            end
            test $verbose -eq 1; and echo "$c_ok→ Created docs/$c_reset"
        end

        for plug in superpowers plans specs
            set -l docs_target   "$docs_dir/$plug"
            set -l agents_target "$plugins_dir/$plug"

            # If a real directory exists in docs/, migrate its contents to AGENTS/plugins/
            if test -d "$docs_target"; and not test -L "$docs_target"
                set -l contents (ls -A "$docs_target" 2>/dev/null)
                if test (count $contents) -gt 0
                    if not command cp -rn "$docs_target/." "$agents_target/"
                        echo "$c_err""Error: could not copy docs/$plug → AGENTS/plugins/$plug$c_reset" >&2
                        return 1
                    end
                end
                if not rm -rf "$docs_target"
                    echo "$c_err""Error: could not remove docs/$plug after copy$c_reset" >&2
                    return 1
                end
                test $verbose -eq 1; and echo "$c_ok→ Moved docs/$plug → AGENTS/plugins/$plug$c_reset"
            end

            # Create symlink docs/<plug> → ../AGENTS/plugins/<plug>
            if not test -L "$docs_target"
                if not ln -s "../AGENTS/plugins/$plug" "$docs_target"
                    echo "$c_err""Error: could not create docs/$plug symlink$c_reset" >&2
                    return 1
                end
                test $verbose -eq 1; and echo "$c_ok→ Linked docs/$plug → AGENTS/plugins/$plug$c_reset"
            end

        end
        if test $verbose -eq 1
            _agents_init_ensure_gitignore "$root" "agents-init --plugins" "docs/superpowers" "docs/plans" "docs/specs"
        else
            _agents_init_ensure_gitignore "$root" "agents-init --plugins" "docs/superpowers" "docs/plans" "docs/specs" >/dev/null
        end
    end

    #   ──────────────────────── Auto-commit AGENTS/ ────────────────────────────
    git -C "$agents_dir" add -A 2>/dev/null
    set -l status_out (git -C "$agents_dir" status --porcelain 2>/dev/null)
    if test -n "$status_out"
        set -l msg "chore: sync AGENTS repository"
        test $did_init -eq 1; and set msg "chore: initialize AGENTS repository"
        if git -C "$agents_dir" -c commit.gpgsign=false commit -q -m "$msg" 2>/dev/null
            if test $verbose -eq 1
                set -l sha (git -C "$agents_dir" rev-parse --short HEAD 2>/dev/null)
                echo "$c_ok→ Committed AGENTS/ ($sha) $c_dim$msg$c_reset"
            end
        end
    end

    test $quiet -eq 1; and echo "$c_head→ Done$c_reset"
end
