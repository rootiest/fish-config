# Contributing to fish-config

This is a personal dotfiles repo, but it's run with practices meant to scale
to a team of contributors, not just one person's solo habits. This document
formalizes those practices so they live somewhere durable instead of only in
commit history and conversation memory. It will grow as the project does —
treat it as a living document, not a final word.

## Table of Contents

- [Getting Started](#getting-started)
- [Branching & Pull Requests](#branching--pull-requests)
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
the docs site wants when it renders, so the SSOT never carries them; see
`docs/site/README.md` for which shapes it recognises.

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
