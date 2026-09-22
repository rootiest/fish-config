# Function CLASSIFICATION schema

This is the canonical definition of the `# CLASSIFICATION` function
doc-header label. It's referenced from code comments and commit messages —
link here, not to anything under `AGENTS/` (that tree is git-ignored local
agent state, not part of the repo).

See [Public function documentation header](../CONTRIBUTING.md#public-function-documentation-header)
in `CONTRIBUTING.md` for where `CLASSIFICATION` fits among the other header
labels, and [C1 — Command Shadows](manual/08-components-reference/01-c1-command-shadows.md)
for the full list of C1-shadowed commands this schema's shadow tags refer to.

## Format

Optional. Comma-separated tags from the closed set below, on the indented
body line directly under the label:

```fish
# CLASSIFICATION
#   uses-shadow(ls), destructive
```

Omit the label entirely when nothing applies — omission means "nothing to
flag," not "not yet audited," so don't add it speculatively, and don't add
it empty as a placeholder.

## Tags

- **`uses-shadow(name[,name...])`** — calls a C1-shadowed command (see the
  C1 doc linked above) bare, deliberately wanting the overridden behavior
  (e.g. `ls` wanting eza's icons for a human to read).
- **`bypasses-shadow(name[,name...])`** — calls `command <name>`,
  `builtin <name>`, or (for `help` specifically) `__original_help $argv`,
  deliberately forcing stock behavior because the shadow's override would
  break this function's logic: timestamps leaking into a parsed capture,
  `-i` prompting on a path meant to run unattended, structural output
  changes breaking a `string`/`sed` parse, etc.
- **`destructive`** — can irreversibly delete or overwrite data: `rm -f`,
  `rm -rf`, truncating or force-overwriting a file, `git push --force`.
  Routine cleanup of the function's own `$tmpdir`/`$_tmpdir`/`mktemp`
  output (or other output it just created in this same call) is expected
  behavior, not a hazard — don't tag it.
- **`network`** — makes an outbound network call: `curl`, `wget`, `ssh`,
  `git fetch`/`pull`/`push`/`clone`, `paru`/`yay` (package-manager network
  ops), talking to an API, etc.
- **`blocking-prompt`** — can block waiting on interactive confirmation
  with no non-interactive escape hatch: a shadow's forced `-i`, fish's
  `read` (genuinely waiting on a terminal — not a `string split | read`
  or `while read` consuming a pipe, which never blocks), a `confirm`-style
  prompt with no `--yes`/`--force`/`--silent` bypass. Don't tag a function
  that's only ever meant to be run interactively at a prompt (a keybinding
  handler, an fzf-driven picker) — the hazard this tag exists for is a
  script or another function calling it unexpectedly, not a human running
  it themselves.

## Placement

Directly under `# DEPENDENCIES` if the header has one; otherwise directly
under `# COMPONENT`; otherwise directly under `# CATEGORY`; otherwise as
the first label in the header block (this is the common case for internal
`_`-prefixed helpers, which usually carry none of the three).

## Judgment calls

`uses-shadow` vs `bypasses-shadow` is the easiest place to get subtly
wrong — verify against the actual code, not just whether the name appears
in the file. A function that only calls a *helper* which itself interacts
with a shadow does not get the tag; the tag belongs on the helper. When
generating these tags in bulk (e.g. delegating the sweep to another
model), review every result against the source before trusting it — this
schema's own rollout caught several false positives this way: a piped
`read` misread as an interactive prompt, a documented `--yes` flag missed
as an escape hatch, and cleanup of a function's own temp output flagged
as `destructive` despite the explicit exclusion above.
