# functions/ conventions

Scoped conventions for writing and documenting files in this directory. Root
conventions (file headers, banners, one-function-per-file, etc.) still apply —
see the project's `AGENTS.md`. This file adds the two rules specific to
function documentation.

**Documentation:** Precede all functions with a UNIX man-page style comment block. This block **is** the published documentation — it generates Section 5 of the manual and the site's function pages.

Labels, in order: `CATEGORY`, `DEPENDENCIES`, `CLASSIFICATION`, `SYNOPSIS`, `DESCRIPTION`, `ARGUMENTS`, `EXIT STATUS`, `RETURNS`, `EXAMPLE`, `NOTES`.

- `CATEGORY` is **required to publish** — a user-facing function without one silently gets no entry (`verify-manual.py` warns). Its value is the bare stem of a `docs/manual/05-functions/*.md` stub, e.g. `04-git-and-version-control`.
- `DEPENDENCIES` is optional: comma-separated names of other functions this one calls, or binaries it requires. The reverse `Used by:` index is generated — never author it.
- `CLASSIFICATION` is optional: comma-separated tags from a closed set, omitted entirely when none apply. Canonical schema (the tag set, placement rule, and judgment-call guidance): `docs/function-classification-schema.md` — that tracked file is the source of truth, not this one; don't duplicate its definitions here.
- `SYNOPSIS`, `DESCRIPTION`, and `EXAMPLE` are enforced by `verify-manual.py`.
- `EXIT STATUS` documents fish's `$status` after the call (the exit-code table). `RETURNS` is reserved for genuine stdout/printed output — omit it entirely for functions that print nothing on success.

**Help Flags:** User-facing functions must accept `-h`/`--help` and print a formatted help menu to `stdout` unless it strictly wraps another tool's help. Functions whose first argument is a subcommand follow the help convention in `CONTRIBUTING.md` (§ Help requests): a bare `help` in the subcommand slot only, `-h`/`--help` anywhere before `--` with no side effects (use `__fish_help_requested`), help on stdout with exit 0 when run bare (unless the default subcommand is read-only), and exit 2 for usage errors. That last rule applies to every user-facing function: use a bare `or return` after `argparse`, and `__fish_no_args` in a function that takes no arguments. List them in `__help_subcommand_fns` and `__help_subcommands` (`tests/test-help.fish`).

## Context & Sub-rules

Before taking action, read and follow the local, untracked instructions in
@AGENTS.local.md if that file exists. It holds machine- and maintainer-specific
rules that are not part of this repository. If it is absent, continue without it.
