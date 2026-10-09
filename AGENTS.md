# AGENTS.md

Instructions for AI coding agents working in this repository: a modular,
guard-railed Fish shell configuration. Human contributors follow the same
rules, in more depth, in `CONTRIBUTING.md`; where the two differ,
`CONTRIBUTING.md` wins.

Scoped rules live next to the code they govern:

- `functions/AGENTS.md`: function documentation headers and help flags.
- `docs/AGENTS.md`: the documentation pipeline and Starlight authoring signals.

## Workflow

- Work on a branch, never directly on `main` (it is protected). Create the
  branch before your first edit.
- Commit as you go, using Conventional Commits (`CONTRIBUTING.md` § Commit
  Conventions).
- Before finishing, `fish tests/run-tests.fish` must **exit 0**. Check its exit
  status, not only the final `TOTAL` line: the lint phases (syntax, indent,
  shadow classification) fail separately from the assertion count.
- Documentation changes: `python3 docs/verify-manual.py` must pass. See
  `docs/AGENTS.md` for which files are generated and must not be hand-edited.

## Coding conventions

1. **File header:** every script and function starts with the license header
   (after any shebang):

   ```fish
   # Copyright (C) 2026 Rootiest
   # SPDX-License-Identifier: AGPL-3.0-or-later
   ```

   Exception: vendored third-party files get no header; their provenance
   lives in `REUSE.toml` (`CONTRIBUTING.md` § Vendored files), and
   `tests/test-license-headers.fish` enforces it.

2. **Banners:** section banners are box-drawing rules, usually a single line
   (`#   ──────── Section ────────`), boxed (`╭─…─╮`) for major blocks.
3. **Functions:** one function per file in `functions/`. No function
   definitions in `config.fish`.
4. **Startup:** `config.fish` ends with a `return` sentinel. Tool inits (e.g.
   `starship init`) go in `conf.d/`, never appended to `config.fish`.
5. **Dependencies:** guard optional binaries with `type -q <binary>`.
6. **Terminals:** gate Kitty/WezTerm-specific behavior behind `$TERM` or
   `$TERM_PROGRAM` checks.
7. **Output:** user-facing output uses the shared palette (`__fish_palette`:
   `$c_err`, `$c_cmd`, …), reset with `$c_reset`. Errors and warnings go to
   stderr. Claude Code hook scripts print only valid JSON on stdout.
8. **Cross-platform:** install scripts detect the package manager (`apt`,
   `dnf`, `pacman`), falling back to Arch/AUR logic.

## Architecture

- **Fisher** is bootstrapped on first run. Several plugins (FZF, Catppuccin,
  done, autopair, puffer-fish) are heavily customized and vendored in
  `conf.d/`. Do not install them via `fisher`.
- **Secrets and machine-specific config** are git-ignored and sourced from
  `~/.config/.user-dots/fish/`. Never commit them.

## Opinionated component guards

Opinionated components are **active by default**, except C5 (below). Six
category variables control them (e.g. `__fish_config_op_aliases`); the full
map is in `docs/manual/08-components-reference/`.

- **Evaluation:** always use `__fish_config_op_enabled`. Never call
  `__fish_variable_check` directly on the guards.
- **Truthiness:** explicit truthy (`1 true yes on y`) enables; explicit falsy
  (`0 false no off n`) disables; case-insensitive. Anything else is treated
  as unset, with a one-time stderr warning.
- **Master switch:** `__fish_config_opinionated=0` disables every category
  whose own variable is unset; explicit category values override it. The
  master is an *off* switch only: a truthy master never enables anything.
- **C5 is opt-in. Do not "fix" this.** `__fish_config_op_logging` defaults to
  **disabled** because it writes terminal output to disk. Unset or
  unrecognized means off, and the master switch cannot enable it; only an
  explicit truthy value does. This is a deliberate special case in
  `__fish_config_op_enabled`.
- **Categories:** C1 (Aliases), C2 (Auto-Exec), C3 (Overrides), C4
  (Integrations), C5 (Logging), C6 (Greeting).
- **Implementation:** wrap `conf.d` components at source time. Gate
  `functions/` shadows inside the function body, falling back to bare
  `command <name> $argv`.

## Gotcha: the fish false-zero

An `if` with no branch taken and no `else` resolves `$status` to **0**, so a
function that ends on such an `if` reports success whatever happened. End
status-bearing functions on an explicit `test $failed -eq 0` or a bare
`return`, never on a trailing `if`. And fixing a helper's exit status is
worthless if its caller discards it: check the call sites too.

## Context & Sub-rules

Before taking action, read and follow the local, untracked instructions in
@AGENTS.local.md if that file exists. It holds machine- and maintainer-specific
rules that are not part of this repository. If it is absent, continue without it.
