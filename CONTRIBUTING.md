# Contributing to fish-config

This is a personal dotfiles repo, but it's run with practices meant to scale
to a team of contributors, not just one person's solo habits. This document
formalizes those practices so they live somewhere durable instead of only in
commit history and conversation memory. It will grow as the project does —
treat it as a living document, not a final word.

## Table of Contents

- [Getting Started](#getting-started)
- [Issues](#issues)
- [Branching & Pull Requests](#branching--pull-requests)
- [Labels](#labels)
- [Commit Conventions](#commit-conventions)
- [Fish Coding Standards](#fish-coding-standards)
- [Opinionated Components](#opinionated-components)
- [Documentation Pipeline](#documentation-pipeline)
- [Testing](#testing)
- [Secrets & Machine-Specific Config](#secrets--machine-specific-config)
- [License](#license)

---

## Getting Started

You'll need [fish 4.x](https://fishshell.com/). Clone the repo and run the
test suite to confirm your environment is sane:

```fish
fish tests/run-tests.fish
```

If you're touching anything under `docs/manual/`, you'll also want `pandoc`,
`python3-yaml`, and Node 24+ to exercise the full doc-build pipeline locally
(see [Documentation Pipeline](#documentation-pipeline)) — otherwise CI will
catch problems on push.

## Issues

Issues live on the Gitea repo. Three templates cover the common cases, each
pre-applying its `Kind/` label; blank issues stay enabled for everything else
— a chore, a refactor, a question, a tracking issue.

| Template | Format | Use it for | Applies |
|---|---|---|---|
| **Bug report** | web form | Something is broken or behaves unexpectedly | `Kind/Bug` |
| **Feature or enhancement request** | markdown | New functionality, or an improvement to what exists | `Kind/Feature` |
| **Documentation issue** | markdown | The manual, man page, `config-help`, or docs site is wrong, missing, or unclear | `Kind/Documentation` |

They live in `.github/ISSUE_TEMPLATE/`, next to the PR template, so the
GitHub mirror offers the same set. The bug report is a Gitea *issue form* —
a real web form with required fields — because a bug report missing its
version, reproduction, or full error text can't be acted on, and a form
refuses to submit without them. The other two are markdown templates in the
same comment-guided style as `.github/PULL_REQUEST_TEMPLATE.md`, since what
they ask for is open-ended prose that structure would only get in the way of.

GitHub reads these same files on the mirror, and its schema differs from
Gitea's in two places, so both are pinned to the spelling that works on both
and each file says so in a comment: the chooser config must be `config.yml`
(GitHub ignores `config.yaml`), and `bug.yml` declares `description:` rather
than `about:` (GitHub requires it; Gitea accepts it as an alias). The two
markdown templates keep `about:`, which is correct for their format on both.

### Issue titles

**Issue titles are plain descriptions of the problem, not Conventional
Commits subjects.**

```text
mv clobbers a symlink when the target exists            ← yes
fix(mv): prompt before replacing an existing symlink    ← no
```

An issue states a problem; a commit states a change. The type and scope that
`fix(mv):` would carry are already on the issue as its `Kind/` and `Area/`
labels, and the conventional subject belongs on the PR that closes it, where
it becomes the commit message. Writing the fix into the title also presumes
one, which is the wrong end to start from for anything still being diagnosed.

### What an issue owes

- **A bug** needs a reproduction someone else can paste and run, starting
  from a fresh shell, plus the complete error output. A stale function
  definition in a long-lived session is the most common false alarm, so
  confirm it survives `exec fish` first. `Status/Need More Info` is where
  reports without a reproduction end up.
- **A feature** needs `## Acceptance criteria` — the checkbox list of what
  must be true for the issue to close. It is the issue-side counterpart to a
  PR's `## Verification`: a definition of done agreed before the work starts
  rather than argued about after, and the PR's checks usually grow out of it.
- **A docs issue** needs to name the `docs/manual/**` source, not just the
  page where the problem showed up. `docs/fish-config.md` and
  `docs/fish-config.1` are generated, and a fix applied there is overwritten
  by the next CI run — see [Documentation
  Pipeline](#documentation-pipeline).

### Triage

Reporters aren't expected to label anything. Contributors without push access
can't, and the templates apply the `Kind/` label by themselves; the rest is
the maintainer's job when the issue is triaged — add the `Area/` label (the
bug form's **Area** dropdown is how a reporter tells you, since no forge can
map a form field to a label), set a `Priority/` if it isn't ordinary, and
apply `Reviewed/Confirmed` once a bug actually reproduces. See
[Labels](#labels).

When a PR resolves an issue it closes it with a trailing `Closes #N` line —
see [Pull request descriptions](#pull-request-descriptions).

## Branching & Pull Requests

**If you don't have push access to this repo**, fork it and open your PR
from a branch on your fork back to `main` here — everything below about
branch naming and commit hygiene still applies, it just happens on your
fork instead of a branch of this repo directly. The rest of this section
assumes you *do* have push access (maintainers, regular contributors).

- **Branch off `main` before starting work.** Don't accumulate uncommitted
  changes directly on `main`. (If you already started editing before
  branching, that's fine — create the branch now, before your first commit;
  branching doesn't touch the working tree.)
- **Merge target is `main`, via PR.** Contributors open the PR; the repo
  owner merges it. Don't merge your own PR.
- **Label every PR.** At minimum one `Kind/` and one `Area/`, same as an
  issue — see [Labels](#labels). If you can't set labels, say what the
  change is in the description and a maintainer applies them.
- **Don't merge until the `## Verification` checklist is fully checked.**
  Unchecked boxes are outstanding manual checks, not decoration. See
  [Pull request descriptions](#pull-request-descriptions) below.
- **Prefix in-progress PRs with `WIP:`.** If the branch still has code
  changes coming, open it as `WIP: type(scope): description`. Gitea
  recognizes the prefix, flags the PR as a draft, and refuses to merge it
  until the prefix is removed; drop it once the branch is complete.

  `WIP:` signals **more changes are coming** — not "done but unverified".
  A finished branch waiting on manual checks is an ordinary PR whose
  `## Verification` boxes aren't all ticked yet; that's already the merge
  gate above and doesn't need the prefix. The two are independent: a PR
  can be WIP with everything ticked, or complete with checks outstanding.
- **Keep feature branches focused.** If you stumble onto something unrelated
  to your current task while working (a pre-existing bug, a stray cleanup),
  don't fold it into the same commit or PR. Handle it with one of these,
  in order of preference:
  1. **Separate branch, separate PR, merged to `main` independently.** The
     default for anything that doesn't overlap the code your current branch
     touches. The two PRs review and merge independently, in either order.
  2. **Separate branch and PR, then sync `main` back into your feature
     branch** once it merges. Use this only when the unrelated fix actually
     touches the same file/function as your feature branch, or your feature
     branch depends on the corrected behavior to work or test correctly.
  3. **Commit directly to `main`.** Reserved for changes too small to
     justify a branch, or genuinely urgent fixes. **Always ask for explicit
     approval before doing this** — there's no standing exception, no matter
     how trivial the change looks.

### Pull request descriptions

Fill in `.github/PULL_REQUEST_TEMPLATE.md` — Gitea pre-loads it into the
description box when you open a PR. Every PR carries, in this order:

- **`## Summary`** — what changed and why, as a short paragraph, 2-5
  bullets, or both. Name concrete paths and identifiers in backticks, and
  explain the reasoning rather than restating the diff.
- **Optional `##` sections** — add what the change actually needs
  (`Root cause`, `Why`, `How it works`, `Behavior`, `Docs`, `Notes`,
  `Scope note`, `Opinionated guard (C1-C6)`), and skip them entirely for a
  straightforward change. A breaking change (title ending in `!` before
  the colon) must include `## ⚠️ Breaking Change` with the migration path.
- **`## Verification`** — always last. Every check this change needs, as a
  checkbox list, each with the exact command and its expected result.
  A **checked** box means verified, whether programmatically (test suite,
  linter, docs verifier, CI) or by hand; check those off before opening the
  PR. An **unchecked** box is an outstanding manual check the reviewer
  still has to perform — leave anything you couldn't verify yourself
  unchecked rather than dropping it.

  **This list is the merge gate: a PR isn't merged until every box is
  checked.** Only list checks that can actually be resolved — one nobody
  can run blocks the PR indefinitely. Put genuinely unverifiable caveats,
  assumptions, and known limitations in `## Notes` instead, where they
  inform the review without gating it.

When a PR resolves a tracked issue, close it with a trailing `Closes #42`
line at the end of `## Summary` — not at the very bottom of the body, since
`## Verification` is always last. `Fixes #N` and `Resolves #N` behave
identically. Repeat the keyword for each issue (`Closes #42, closes #43`); a
bare `#43` is only a link and won't close anything. To point at a related
issue that should stay open, drop the keyword and use `Refs #42`. Leave the
line out entirely when no issue is involved.

## Labels

**Every issue and every pull request carries exactly one `Kind/` label and at
least one `Area/` label.** Everything else is optional, and most of it is
applied by a maintainer at triage rather than by whoever opened the thing.

Labels are scoped: the `Group/Name` form renders as a two-tone chip in Gitea,
and for the three *exclusive* groups below Gitea enforces one-at-a-time by
swapping the old label out when you apply a new one.

### `Kind/` — what this is

Required, and by convention exactly one. Gitea doesn't enforce one-of here,
so pick the dominant character of the change instead of stacking two.

| Label | For |
|---|---|
| `Kind/Bug` | Something is not working |
| `Kind/Feature` | New functionality |
| `Kind/Enhancement` | Improves functionality that already exists |
| `Kind/Documentation` | Documentation changes |
| `Kind/Testing` | The test suite itself |
| `Kind/Refactor` | Restructures code without changing behavior |
| `Kind/Chore` | Tooling, dependencies, housekeeping |
| `Kind/Performance` | Makes existing behavior faster or lighter |
| `Kind/Security` | A security issue |

These deliberately mirror the Conventional Commits types in [Commit
Conventions](#commit-conventions), so a PR's label and its title agree:
`fix` → `Kind/Bug`, `feat` → `Kind/Feature` or `Kind/Enhancement`, `docs` →
`Kind/Documentation`, `test` → `Kind/Testing`, `refactor` →
`Kind/Refactor`, `chore` → `Kind/Chore`, `perf` → `Kind/Performance`.

### `Area/` — what it touches

Required, and non-exclusive on purpose: a change that adds a function, its
completions, and a manual entry gets all three.

| Label | Covers |
|---|---|
| `Area/Functions` | `functions/` |
| `Area/Completions` | `completions/` |
| `Area/Config` | `config.fish`, `conf.d/` — startup and environment |
| `Area/Docs` | `docs/manual/` and the generated manual, man page, and site |
| `Area/Tests` | `tests/` |
| `Area/CI` | `.github/workflows/` and repository automation |
| `Area/Integrations` | `integrations/` |
| `Area/Prompt & Theme` | `themes/` and prompt appearance |
| `Area/Components` | The opinionated-component system (C1-C6) |
| `Area/Scripts` | `scripts/` |

`Area/` is what makes the tracker searchable: it answers "what's still
outstanding in the docs pipeline?" in a way `Kind/` never can. Two edges
worth naming — `Area/Docs` covers the documentation *and its pipeline*, so
`README.md` and this file count even though they sit outside `docs/`; and
`Area/Components` is for the C1-C6 machinery itself, not for every function
that happens to carry a `# COMPONENT` header.

### `Compat/Breaking`

Applied to **any PR whose title carries `!` before the colon**, and to any
issue proposing a change that would. It travels with the `## ⚠️ Breaking
Change` section that such a PR must already include — see [Pull request
descriptions](#pull-request-descriptions).

### `Priority/` — exclusive, maintainer-applied

`Priority/Critical`, `Priority/High`, `Priority/Medium`, `Priority/Low`.

**No priority label means ordinary priority.** Labeling everything defeats
the point, so leave it off unless the item is genuinely more or less urgent
than the rest of the queue.

### `Reviewed/` — exclusive, maintainer-applied

`Reviewed/Confirmed` goes on a bug that has actually been reproduced —
that's the signal separating a report from a known defect.
`Reviewed/Duplicate`, `Reviewed/Invalid`, and `Reviewed/Won't Fix` accompany
closing an issue, always with a comment saying why; a close with only a
label on it is not an explanation.

### `Status/` — exclusive, maintainer-applied

`Status/Blocked`, `Status/Need More Info`, `Status/Abandoned`. These describe
the item's current state, so remove one as soon as it stops being true — a
stale `Status/Need More Info` on an issue that got its answer is worse than
no label, because it reads as still waiting.

### `good first issue` and `help wanted`

Invitations to contributors, applied by a maintainer. Both are deliberately
**unscoped**: they'd be a natural fit under `Status/`, but that group is
exclusive, and an issue is quite often both blocked on something *and* open
for someone to pick up. Keeping them outside the group lets them coexist
with a real status.

Use `good first issue` for work that is genuinely self-contained — a clear
acceptance criterion, one or two files, no need to understand the
opinionated-component system first.

### The GitHub mirror

The repo is mirrored to
[github.com/rootiest/fish-config](https://github.com/rootiest/fish-config),
and **the mirror carries the same labels, by the same names**. That isn't
cosmetic: GitHub reads the same `.github/ISSUE_TEMPLATE/` files, and a
`labels:` entry naming a label that doesn't exist on that side is silently
dropped rather than reported. Mirroring copies files, not repository
settings, so **a label added here must be created on the mirror too** — no
automation does it for you.

One behavioral difference to keep in mind: **GitHub has no exclusive
labels.** Gitea enforces one-at-a-time on `Priority/`, `Reviewed/`, and
`Status/` by swapping the old label out; on the mirror those are ordinary
labels and nothing stops two of a group coexisting, so there the one-of rule
holds by convention alone.

Issues and pull requests belong on the canonical Gitea repo — the template
chooser links there first, on both sides. The mirror's tracker stays open so
that a report which lands there anyway isn't lost, not because it's a second
supported front door.

## Commit Conventions

Commit subjects follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description
```

Types currently in use in this repo: `feat`, `fix`, `docs`, `test`, `chore`,
`perf`. The scope is usually the function, component, or subsystem touched
(e.g. `feat(help): ...`, `fix(scrub): ...`, `chore(docs): ...`). Look at
`git log` for recent examples before picking a type/scope for something
novel.

## Fish Coding Standards

### File header

Every hand-authored `.fish` file starts with:

```fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
```

(A few completion scripts adapted directly from a tool's own upstream
completions keep that tool's original attribution comment instead of this
header — match whichever convention the specific file already follows. New
files use the standard header above.)

### Public function documentation header

Every user-facing function gets a machine-parsed comment header directly
above its `function` line. This header is the single source of truth for
the generated manual (`docs/fish-config.md` / the man page / the docs
site) — see [Documentation Pipeline](#documentation-pipeline) for how it
gets consumed. The parser (`docs/manualtools.py`) recognizes these labels,
all optional except where noted:

| Label | Purpose |
|---|---|
| `CATEGORY` | **Required to appear in the manual at all** — see below. |
| `COMPONENT` | Only for functions gated by the [opinionated-component system](#opinionated-components). |
| `DEPENDENCIES` | Other functions this one calls that a reader may want to look up. |
| `SYNOPSIS` | One-line usage form. |
| `DESCRIPTION` | Prose description; can span multiple paragraphs. |
| `ARGUMENTS` | Flags/positional args, one per line. |
| `EXIT STATUS` | Exit codes and what they mean. |
| `RETURNS` | For functions used for their output/return value rather than exit status. |
| `EXAMPLE` | One or more realistic invocations. |
| `NOTES` | Anything else worth flagging (fallback behavior, caveats, gotchas). |

A full example (`functions/claude.fish`):

```fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# COMPONENT
#   aliases/dev-tools
#
# DEPENDENCIES
#   agents-init
#
# SYNOPSIS
#   claude [ARGS...]
#
# DESCRIPTION
#   Wrapper for the claude CLI that ensures the AGENTS/ sub-repository is
#   initialized and any agent-made changes are committed before launch.
#   ...
```

**`CATEGORY` is the opt-in gate for the manual:** a function with no
`# CATEGORY` line produces no manual entry at all — this is how bundled
plugin internals and prompt guts stay out of user-facing docs without an
exclusion list. `CATEGORY` must exactly match one of the existing
`docs/manual/05-functions/NN-*.md` stubs:

```
01-file-and-directory      08-terminal-management
02-navigation               09-clipboard
03-editors-and-viewers      10-network
04-git-and-version-control  11-pager-and-logging
05-package-management       12-ai-and-developer-tools
06-dependency-management    13-media-and-utilities
07-system-and-monitoring    14-miscellaneous
```

If your function genuinely doesn't fit any of these, add a new
`docs/manual/05-functions/NN-your-category.md` stub (with frontmatter
matching its siblings) rather than force-fitting it into an existing one.

### Private/internal helper functions

Functions named with a leading `_` (e.g. `_agents_init_ensure_gitignore`,
`__fish_config_op_enabled`) are excluded from the manual unconditionally,
regardless of whether they carry a `CATEGORY` line — so they generally don't
have one. They should still carry the standard file header, and a lighter
`SYNOPSIS`/`DESCRIPTION` comment is encouraged wherever the function's
purpose or calling convention isn't obvious from its body, matching the
convention already used across `__fish_config_op_*.fish` and similar files.

### Function declaration

Give every function a `--description`, since it's what shows up in `fish -c
'functions'`/completions and other introspection:

```fish
function my_function --description 'Short, imperative description'
```

### Colored `--help` output

Every function with a `-h`/`--help` flag uses this standardized color
palette (established across the codebase 2026-08-22):

```fish
set -l c_head  (set_color --bold cyan)   # section headers
set -l c_cmd   (set_color --bold)        # the command name itself (theme-adaptive)
set -l c_flag  (set_color yellow)        # flags
set -l c_arg   (set_color cyan)          # required-argument placeholders
set -l c_dim   (set_color brblack)       # optional-argument placeholders
set -l c_ok    (set_color green)         # success/positive status
set -l c_warn  (set_color yellow)        # warnings
set -l c_err   (set_color red)           # errors
set -l c_reset (set_color normal)
```

Not every function needs every variable — pull in only the ones your help
text actually uses. Structure the usage block as `Usage:`, then sections
for arguments/flags/examples as needed; see `functions/rand_string.fish` or
any recently-touched function for a full worked example.

## Opinionated Components

Some functionality in this config is classified into one of six toggleable
categories (C1–C6: aliases, autoexec, overrides, integrations, logging,
greeting) plus sub-categories, so users can disable pieces of it via
`config-settings` or universal variables. If you're adding something that
shadows a builtin, runs at startup, overrides a key binding/environment
variable, or otherwise falls under an existing category, tag it with a
`# COMPONENT` header (`<category>/<subcategory>`, e.g.
`overrides/key-bindings`) and guard it with `__fish_config_op_enabled`. See
the [README's Minimal Mode section](README.md#minimal-mode) for the full
category list and toggle semantics, and
`AGENTS/specs/2026-08-17-opinionated-component-subcategories-design.md` for
the underlying design. Most new functions are *not* opinionated components
— only tag something if it fits an existing category; this isn't something
to force.

## Documentation Pipeline

`docs/manual/` is the single source of truth for the user manual, man page,
and documentation site. **Never hand-edit `docs/fish-config.md` or
`docs/fish-config.1`** — they're generated by `docs/build-manual.py` from
`docs/manual/**` plus every function's doc-header (see above), verified by
`docs/verify-manual.py`, and auto-committed by CI on push to `main`
(`chore(docs): regenerate manual, man page, and component registry`).

If you're changing something under `docs/manual/` directly, or adding a
function whose `CATEGORY`/`COMPONENT` header should surface new content, you
can build and check it locally before pushing:

```fish
python3 docs/build-manual.py --concat -o docs/fish-config.md
python3 docs/verify-manual.py
```

CI runs the same verification and regenerates the site/man page — a broken
manual won't get published, but running it locally saves a round trip.

Write doc-headers as plain text — no backticks. `-a/--all`,
`__fish_config_op_aliases` and `~/.config/fish/config.fish` are typed
bare, because the header is also read as-is by `config-help` and by
anyone opening the file. `docs/codespans.py` adds the inline code spans
when it renders, so the SSOT never carries them; see
`docs/site/README.md` for which shapes it recognises. That pass runs for
every output — the site, the man page and `config-help` — so a token is
typeset the same way wherever it is read.

Two rules apply to backticks you write under `docs/manual/` as well:

- **Never inside an indented block.** A four-space block is verbatim in
  every renderer, so a backtick there is a literal character on the page
  rather than markup.
- **Never wrapped across a line break.** Markdown accepts a span split
  over two lines, but `config-help` pairs backticks one line at a time
  and would show the halves literally. Reflow the sentence instead.

`docs/verify-manual.py` enforces both.

## Testing

```fish
fish tests/run-tests.fish
```

Runs before every push and gates the documentation build in CI. Two phases:

1. **Syntax lint** — every tracked `.fish` file (`config.fish`, `functions/`,
   `conf.d/`, `completions/`, `integrations/`) is checked with `fish -n`.
2. **Sandboxed functional checks** — the config is copied into a throwaway
   `HOME`/`XDG_CONFIG_HOME` sandbox (never this checkout itself, since it
   doubles as a real `~/.config/fish`) and loaded as an isolated interactive
   session. `tests/functional.fish` then runs against foundational behavior:
   XDG/PATH/CDPATH setup, key bindings, abbreviations, core functions, the
   opinionated-component registry, and more.

To add a new functional check, add a `test_*` function to
`tests/functional.fish` — it's picked up automatically by
`functional_test_main`, no registration needed. Return 0 on pass, non-zero
on fail; print a short diagnostic on failure.

## Secrets & Machine-Specific Config

**Nothing containing credentials, tokens, personal identifiers, or a
specific machine's paths belongs in this repo — not even in a PR.** That
kind of thing lives in each user's own private overlay
(`~/.config/.user-dots/fish/secrets.fish` and `local.fish`), which is
git-ignored by design. If you're writing something that needs a secret or a
machine-specific path, source it from there rather than hardcoding it.
Everything else — general-purpose, reusable across machines — belongs in
the tracked repo as normal. See [README's Personalization
section](README.md#personalization) and
[`docs/manual/07-customization.md`](docs/manual/07-customization.md) for the
full mechanics.

## License

This project is licensed under AGPL-3.0-or-later (see `LICENSE`). Every new
hand-authored file needs the SPDX header shown in [File
header](#file-header) above.
