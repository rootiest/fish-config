---
name: Documentation issue
about: Something in the manual, man page, config-help, or docs site is wrong, missing, or unclear
labels:
  - Kind/Documentation
---

<!--
  Title this as a plain description of the problem:

      config-help shows literal backticks in the customization section

  not `docs(help): ...`. See CONTRIBUTING.md § Labels.

  Docs in this repo are GENERATED. docs/manual/** plus the doc-header
  comments above each function are the single source of truth;
  docs/fish-config.md and docs/fish-config.1 are build output and are never
  hand-edited. So a fix always lands in the source, not in the page where you
  saw the problem — the Location section below asks for both.

  Delete these comments as you fill it in.
-->

## Location

<!--
  Where you saw it, and where it actually comes from.

  - **Where you saw it** — the docs site URL, the `config-help <topic>` you
    ran, `man fish-config`, or the README section.
  - **Source file** — the docs/manual/** page, or the function whose
    doc-header feeds it (e.g. `functions/mv.fish`). If you're not sure which,
    say so and leave it to triage rather than guessing.

  If the problem appears in one output but not the others — correct on the
  site, broken in the pager — say which, since that usually points at the
  rendering pass (docs/codespans.py) rather than the source text.
-->

## Problem

<!--
  What's wrong. Quote the current text so it can be found and compared.
  Common shapes, if it helps you place yours:

  - **Wrong** — documents behavior the code doesn't have.
  - **Stale** — described a flag or path that has since changed.
  - **Missing** — a function, flag, or setting with no entry at all. Note
    that a function with no `# CATEGORY` header is omitted from the manual
    deliberately, so "missing" may be an intentional opt-out.
  - **Unclear** — accurate, but a reader can't act on it. Say what you
    expected to learn and what you concluded instead.
  - **Renders wrong** — a broken code span, a mangled table, a bad anchor.
-->

## Suggested fix

<!--
  Proposed wording or structure, if you have one — a diff-shaped
  before/after is ideal, but a rough sketch is welcome too. "I don't know
  what it should say, only that this confused me" is a legitimate and useful
  report; keep the heading and say that.

  Two constraints on any text under docs/manual/, both enforced by
  docs/verify-manual.py:

  - No backticks inside an indented block.
  - No backtick span wrapped across a line break.

  Doc-headers in .fish files take no backticks at all — docs/codespans.py
  adds code spans when it renders. See CONTRIBUTING.md § Documentation
  Pipeline.
-->

## Notes

<!--
  Anything else — related issues (`Refs #42`), the commit that introduced the
  problem, other pages with the same mistake. Drop this heading if empty.
-->
