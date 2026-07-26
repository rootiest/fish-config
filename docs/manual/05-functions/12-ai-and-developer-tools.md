---
title: AI and Developer Tools
manTitle: 5.12 AI and Developer Tools
sidebar:
  order: 12
helpKeywords:
- ai
---

## agy

    Synopsis:  agy [args...]
    Wrapper for the agy Antigravity AI CLI. Before launching, delegates to
    agents-init --agents to ensure AGENTS/ is scaffolded and CLAUDE.md is
    symlinked to AGENTS/AGENTS.md in the current project, then forwards all
    arguments verbatim to the real agy binary. Command shadow (C1): when
    __fish_config_op_aliases (or the master) is disabled, the call is
    passed through to the real agy binary unchanged.

    agy chat
    agy resume

## antigravity-ide

    Synopsis:  antigravity-ide [args...]
    Runs the antigravity-ide editor with warnings filtered.

## agents-init

    Synopsis:  agents-init [--agents | --plugins]
    Scaffold an AGENTS/ sub-repository for tracking agent specs, plans, specs,
    and dev logs. Creates AGENTS/ as a standalone git repo, moves any existing
    AGENTS.md into it, and replaces it with a relative symlink (plus
    CLAUDE.md -> AGENTS/AGENTS.md so Claude Code picks up the shared agent
    instructions). Consolidates plans/ and specs/ directly under AGENTS/
    (merging any legacy docs/plans, docs/superpowers/plans, or old
    AGENTS/plugins/ locations into the canonical AGENTS/<tgt>), creates
    AGENTS/devlogs/, and wires docs/superpowers/{plans,specs} symlinks back to
    them. Adds managed paths to .gitignore and auto-commits every change inside
    the AGENTS/ sub-repo; pulls first when the sub-repo has an upstream.
    Fully idempotent: a second run produces no output and no new commits.
    Flags: --agents re-runs only the AGENTS.md / symlink step; --plugins
    re-runs only the plans/specs/devlogs wiring step. Called automatically by
    the claude and agy wrappers on every invocation.

    Structure versioning: each AGENTS/ repo carries a self-contained version
    bumper. AGENTS/.version holds MAJOR.MINOR.PATCH (seeded 1.0.0). Committed
    git hooks under AGENTS/.agents-tools/ (wired via core.hooksPath) bump it on
    every commit: MINOR (resetting PATCH) when the tracked directory set
    changes, PATCH otherwise; MAJOR is manual-only. A prepare-commit-msg hook
    appends "(vX.Y.Z)" to the commit subject. Downstream tooling can read
    AGENTS/.version - a changed MINOR field signals a structure change. Because
    core.hooksPath is a single setting, the local override would otherwise
    shadow your global hooks; after bumping the version, each shim chains
    (execs) to the global/system core.hooksPath hook of the same name so global
    pre-commit / prepare-commit-msg hooks (e.g. ggshield, Git LFS) still run.
    The script and hooks are shipped from scripts/agents-tools/ and refreshed
    when their version marker is stale.

    agents-init
    agents-init --agents
    agents-init --plugins

## claude

    Synopsis:  claude [args...]
    Wrapper for the claude CLI. Before launching, delegates to agents-init
    --agents to ensure AGENTS/ is scaffolded and CLAUDE.md is symlinked to
    AGENTS/AGENTS.md in the current project, then forwards all arguments
    verbatim to the real claude binary. Command shadow (C1): when
    __fish_config_op_aliases (or the master) is disabled, the call is
    passed through to the real claude binary unchanged.

    claude
    claude --resume

## claude-docs

    Synopsis:  claude-docs
    Invokes Claude Code to analyze recent repository changes and update
    README.md, ensuring all documented features and examples are accurate.

## claude-pr

    Synopsis:  claude-pr
    Invokes Claude Code to run the full PR workflow: create branch,
    conventional commit, verification, push, and open a PR with a manual
    verification checklist.

## qc

    Synopsis:  qc [prompt...]
    Quick-chat wrapper around the aichat LLM CLI that defaults to the "cli"
    role - a system prompt tuned for concise, terminal-friendly output. On
    first use it installs the bundled role by symlinking
    scripts/cli-agent.md to $XDG_CONFIG_HOME/aichat/roles/cli.md (creating
    the directory if needed). Inherits every aichat flag and tab completion
    (--wraps aichat); passing --role/-r overrides the default role, so qc
    forwards to aichat unchanged. The function is only defined when aichat
    is installed. Run qc --help for aichat's full flag reference with the
    command name rewritten to qc.

    qc "how do I list open ports on linux?"
    qc -m ollama:llama3 "explain this error"
    qc --role coder "refactor this function"

## superpowers

    Synopsis:  superpowers [on|off] [-g]
    Enables or disables the Superpowers plugin for Antigravity and Claude
    Code at workspace/project scope (default) or user scope (-g/--global).

    superpowers on
    superpowers off -g

---
