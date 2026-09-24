---
title: AI Agent Tooling
manTitle: 16. AI AGENT TOOLING
sidebar:
  order: 20
helpKeywords:
- agent
- agents-init
- agents-vault
- AGENTS.md
- claude-code
- agy
- antigravity
---
This section explains the machinery behind AI coding agents (Claude Code,
Antigravity/agy) working in a project checked out from this configuration:
where their instructions live, how they get there, and the safety rules
that keep an agent's launch-time bookkeeping from touching a repository's
own tracked history. Command-line usage for the functions named here
(`agents-init`, `agents-vault`) is generated from their own doc headers —
see Section 5.


## The problem this solves

An AI coding agent needs a persistent, project-scoped place to keep
instructions, memory, and working notes. Committing that material directly
into a project's normal history mixes two concerns that change at
different rates and for different reasons: the project's own code, and an
agent's evolving working state. It also means every project accumulates
its own copy of agent tooling (hooks, version files, convention
documents) that has nothing to do with that project's actual purpose.

`agents-init` and `agents-vault` exist to keep that material out of the
main repository while still making it feel local: an agent reads and
writes `AGENTS.md` exactly where it would expect to find it, but the real
content and its history live in a separate, self-contained git repository
that the main project never tracks.


## The AGENTS.md convention

`AGENTS.md` is a plain-text file at a project's root (and, as this
configuration extends the idea, at the root of any subdirectory with its
own scoped conventions) that an AI agent reads for repository-specific
instructions. It has become a convention shared across coding agents, not
one tool's proprietary format.

Claude Code originally required its own `CLAUDE.md` filename specifically.
It now reads `AGENTS.md` natively whenever no `CLAUDE.md` is present, which
retired the need for this configuration to create, maintain, or symlink
`CLAUDE.md` at all. A project scaffolded by `agents-init` today carries
only `AGENTS.md` — at the root, and in any subdirectory that has grown its
own scoped conventions (`functions/`, `docs/`, and so on, in this
repository's own case). A leftover `CLAUDE.md` from before this change is
retired automatically the next time `agents-init` runs: renamed, not
preserved under its old name, so nothing is ever left tracking two copies
of the same instructions under two different filenames.


## The AGENTS/ sub-repository

`agents-init` scaffolds a directory named `AGENTS/` at a project's root.
It is a self-contained git repository — its own `.git`, its own commit
history, its own hooks — and it is gitignored from the project it lives
inside. The project's own `AGENTS.md` (and every subdirectory's) is a
symlink into it:

    $PROJECT/AGENTS/
    ├── AGENTS.md         Canonical root agent spec (real file)
    ├── functions/AGENTS.md Canonical spec for functions/, and likewise for any other scoped subdirectory
    ├── plans/            Superpowers implementation plans
    ├── specs/            Superpowers design specs
    ├── devlogs/          Agent development logs
    ├── .version          MAJOR.MINOR.PATCH structure version
    └── .agents-tools/    Version-bump script and git hook shims (committed)

An agent editing `$PROJECT/AGENTS.md` is, transparently, editing
`$PROJECT/AGENTS/AGENTS.md` — the file-editing tools most agents ship with
resolve a symlinked directory's contents normally, but they cannot write
*through* a symlinked file itself, which is why the seed content
`agents-init` writes for a brand-new project spells this out directly to
the agent reading it.

IMPORTANT: This means an agent must never try to write to a *symlink
named* `AGENTS.md` directly. The seed instructions `agents-init` writes
for a fresh project tell the agent this explicitly, pointing it at the
real file inside `AGENTS/`.

### Version tracking and hooks

Every `AGENTS/` repository carries a `.version` file (seeded `1.0.0`) and
a self-contained version bumper, wired through `core.hooksPath` rather
than the ordinary `.git/hooks/` directory:

  - A **pre-commit** hook bumps `.version` on every commit: the MINOR
    field moves when the set of tracked top-level directories changes
    (a new subdirectory convention was adopted, or one was dropped), the
    PATCH field otherwise. The MAJOR field is manual-only.
  - A **prepare-commit-msg** hook appends `(vX.Y.Z)` to the commit
    subject, so the version history is legible from `git log` alone.

Each hook shim then chains to whatever hook of the same name the
project's *global* or *system* `core.hooksPath` already points at — a
credential scanner like ggshield, Git LFS, or anything else already
wired in ahead of this. Pointing `core.hooksPath` at `.agents-tools/hooks`
locally does not shadow those; it runs both.

The `.agents-tools/` scripts themselves are copied in from this
configuration's own `scripts/agents-tools/` and refreshed automatically
whenever their version marker moves, so every project's `AGENTS/`
repository stays current with this configuration without any manual step.

Downstream tooling that wants to know whether a project's `AGENTS/`
*structure* changed — as opposed to just its content — can read the
`.version` file's MINOR field directly rather than diffing the tree.


## Per-directory discovery

The convention is not limited to a project's root. Any directory that
carries its own `AGENTS.md` — `functions/`, `docs/`, or a subdirectory of
a much larger project with genuinely distinct conventions of its own —
gets the identical treatment: a real file inside `AGENTS/<that path>/`,
and a symlink at the project location pointing back to it. `agents-init`
finds these automatically on every run, rather than working from a fixed
list, by walking the project tree for any file literally named
`AGENTS.md` or `CLAUDE.md`.

Each directory found is settled into exactly one of four states, in
order, so a later run only ever sees a directory that is already
consistent:

  1. **An inverted mirror** (an older layout, where `CLAUDE.md` was the
     real file inside `AGENTS/` and `AGENTS.md` was symlinked to it) is
     flipped in place — same bytes, new name.
  2. **A real file at the project level, with no real file inside
     `AGENTS/` yet**, is adopted: a lone `AGENTS.md` moves in as-is; a
     lone `CLAUDE.md` is renamed on the way in, never preserved under its
     own name. When both `AGENTS.md` and `CLAUDE.md` are real files at
     once, byte-identical content is deduplicated (the `AGENTS.md` side is
     kept); different content is left exactly as it is, with a warning —
     this function has no way to know which one is authoritative, and
     guessing wrong would silently discard the other.
  3. **A stray `CLAUDE.md` inside `AGENTS/`** left over once `AGENTS.md`
     is settled there is removed — nothing named `CLAUDE.md` survives
     inside the mirror.
  4. **The project-level symlink** is created or repaired if missing or
     stale, and any `CLAUDE.md` still at the project level is removed. A
     real file that turns up here *after* the mirror already settled (for
     instance, an agent's own `/init`-style command writing a fresh
     `CLAUDE.md`) is held to the same identical-or-differ rule as step 2:
     a duplicate is dropped, anything different is left alone with a
     warning rather than silently overwritten.


## Safety: what discovery will never touch

Because discovery walks the whole project tree rather than a fixed list,
it deliberately prunes several classes of directory before it ever
considers what's inside them:

  - **Anything outside the project entirely.** A directory that has no
    git repository of its own, but happens to carry a lone `AGENTS.md` or
    `CLAUDE.md` (a home directory scaffolded this way, for instance), is
    synced at that single location only — no recursive walk runs at all.
    Recursive discovery only ever runs inside a real git repository.
  - **Nested repositories.** Any subdirectory that is itself a git
    repository — a submodule, a nested clone, a plugin checked out inside
    a tool's own state directory — belongs to a different project and is
    never walked into.
  - **Dot-directories.** Anything named starting with `.` (`.git`,
    `.claude`, `.gemini`, `.github`, and so on) is a tool's own state or
    configuration, not a project's own scoped convention, and is skipped
    unconditionally.
  - **Generated output.** `build/`, `dist/`, `out/`, and `target/`
    directories are never inspected — nothing generated by a build step
    is a source of hand-authored instructions.
  - **`node_modules/`**, and any directory literally named `AGENTS` other
    than the current project's own mirror.


## Safety: deliberately tracked files are left alone

Discovery can reach a directory whose `AGENTS.md` or `CLAUDE.md` is
already committed to the project's own history on purpose — a team's
shared conventions file in a monorepo subdirectory, for instance, tracked
long before this configuration's owner ever cloned it. Replacing that
file with a symlink would change it from an ordinary tracked file into a
link pointing outside the repository the moment `agents-init` next runs,
which is not a decision this tool should make unattended on someone
else's behalf.

A real file is left untouched, instead of adopted or replaced, whenever
**both** of the following hold:

  - it is tracked in git's index — staged or committed, checked with
    `git ls-files`. A file that has never been `git add`ed is not tracked
    by this definition, even if it sits right next to files that are.
  - the project's `.gitignore` actually exists and has content in it.

Neither condition alone is enough to protect a file. An untracked file is
always safe to adopt, regardless of what `.gitignore` says about it
(nothing has been committed yet, so nothing is lost). A tracked file in a
project with *no* established ignore conventions at all — no
`.gitignore`, or an empty one — is treated as the very first time this
convention has been applied to that project, rather than a deliberate
choice to keep tracking it: `agents-init` adopts it the same way it would
adopt any other real file, which is the same behavior this tool has
always had for a project's own root file.

NOTE: In practice, this means a mature project with an established
`.gitignore` will have any already-committed `AGENTS.md`/`CLAUDE.md` left
alone across the board — root included — and will only ever adopt one
during that project's first encounter with this convention, before a
`.gitignore` entry for it exists yet.

When a directory is skipped for this reason, `agents-init` prints a
warning naming the file and explaining why, rather than staying silent
about a directory it chose not to touch.


## plans/, specs/, and devlogs/

`agents-init --plugins` (the second half of what a bare `agents-init` run
does) wires up three more directories inside `AGENTS/`: `plans/` and
`specs/` for the superpowers skills' implementation plans and design
documents, and `devlogs/` for agent-authored development notes. Real
content from every legacy location this configuration has ever used for
these (`docs/plans`, `docs/superpowers/plans`, and an older
`AGENTS/plugins/` layer from before the sub-repository consolidated them)
is merged into the canonical `AGENTS/plans` and `AGENTS/specs` on first
run, and the legacy locations are removed once merged.

`docs/superpowers/plans` and `docs/superpowers/specs` are always
symlinked to their `AGENTS/` counterparts, because the superpowers skills
expect to find them there by default. `docs/plans`, `docs/specs`, and
`docs/devlogs` are only created as symlinks when a project already had a
real directory by that name — nothing forces those paths to exist for a
project that never used them.


## The launch lifecycle

The `claude` and `agy` wrapper functions each run `agents-init --quiet`
(full setup: both the `AGENTS.md` symlink step and the plans/specs/devlogs
wiring) before launching the real CLI, on every invocation. This is what
makes the whole system self-healing: a project that has drifted from the
expected layout — a stale symlink, a newly-added subdirectory's
instructions not yet adopted, a leftover `CLAUDE.md` — is corrected
automatically the next time an agent is launched there, with no separate
setup step for a person to remember.

At the end of every `agents-init` run, any uncommitted change inside
`AGENTS/` is committed automatically, so whatever an agent wrote during
its session is captured without anyone needing to run `git add` on a
repository they were never meant to think about directly. That commit is
strictly local: `agents-init` never fetches or pushes, because a network
round trip running synchronously ahead of every agent launch would block
the launch itself for as long as an unreachable remote takes to time out.
A project's `AGENTS/` repository that has its own upstream is pulled and
pushed by hand, on its owner's own schedule.

`agents-vault` is a related but distinct tool: where `AGENTS/` holds
*one project's* agent state, `agents-vault` backs up curated agent memory
that lives *outside* any project tree entirely — `~/.claude/projects/*/memory`
and similar host-scoped locations — into its own host-scoped repository.
The `claude`/`agy` wrappers sync both on every launch. See
`__fish_agent_vault_autopush` in Section 7 for its one user-facing
configuration variable; command-line usage for both tools is in Section 5.
