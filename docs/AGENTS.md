# docs/ conventions

## Documentation Policy (SSOT)

There are **two** sources of truth, split by content type:

- **`docs/manual/**`** — prose for every section *except* function entries.
  Each file carries YAML frontmatter; `title` is the site heading and
  `manTitle` is the verbatim man-page heading.
- **`functions/*.fish` comment headers** — Section 5 (Functions Reference).
  Entries are generated from the header, so there is no Markdown copy to
  keep in sync. `docs/manual/05-functions/*.md` are frontmatter-only stubs
  supplying category order, titles, and `helpKeywords`. **Do not add `##`
  entries to them** — edit the function's header instead.

Rules:

- You MUST update the relevant source when adding/changing functions,
  bindings, or variables.
- `docs/fish-config.md`, `docs/fish-config.1`, and `docs/site/src/content/docs/`
  are **generated**. Never edit them directly.
- Run `python3 docs/verify-manual.py` before committing docs changes.
- `docs/fish-config.index` is still hand-maintained until Phase 4.
- Site-only fenced code blocks use Starlight's title/filename convention
  (e.g. `` ```fish title="Usage" ``) — see
  [Frames and titles](https://starlight.astro.build/guides/authoring-content/#frames-and-titles).
  `build-manual.py`'s `_prettify_block` sets this automatically for
  function entries: the Synopsis fence is titled `"Usage"`, and an
  `EXAMPLE` block is titled `"Examples"` (triggered by a flat `Example:`
  label line, mirroring the existing `Synopsis:` handling in
  `render_entry`). `docs/manual/**` prose pages cannot carry hand-added
  titles the same way — `test_prettify_is_site_only` forbids literal
  fences in the SSOT, since `prettify()` only runs at site-build time and
  the man-page/`config-help` pipeline reads the indented form untouched.
  Instead, `_render_para` recognizes authored signals already valid in
  indented prose: a bare single-line path ending in a known extension
  (titled by its basename), a leading `# in <file>` / `# <file>` comment on
  an otherwise-shell paragraph (promoted to the title and stripped from the
  rendered body), and — for a shell paragraph a filename comment doesn't
  fit — a leading `# Label` comment (e.g. `# Arch / AUR` heading a distro's
  install command). `_label_title` is what tells a label from an
  explanation: it's promoted only when short (≤48 chars, ≤8 words) and
  doesn't end in sentence punctuation (`.!?;:,`); a comment like
  `# Turn it off:` stays a literal comment. Use these to title a prose code
  block instead of inventing new syntax.

  `_is_shell` recognizes a command name from `SHELL_HEADS` plus the same
  code vocabulary `codespans` wraps in backticks (repo function names and
  the `fish-deps` catalog included) — one shared list, so a custom command
  like `fish-deps` or `config-settings` doesn't need a second manual entry
  to get shell highlighting.

  Two more authored signals convert flat SSOT text into Starlight
  components, both site-build-time-only (the man page/`config-help`
  pipeline reads the plain text untouched):

  - **Labeled callouts:** a flat paragraph whose first line matches
    `LABEL:` (from a closed set — `NOTE`, `IMPORTANT`, `TIP`, `HINT`,
    `WARNING`, `CAUTION`, `DANGER`) becomes a Starlight `<Aside>`. The
    label line and any following lines up to the next blank line become
    the aside body — write the label with no blank line before an
    attached list, or the list becomes a separate untouched paragraph.

    | Label | Type | Title | Icon |
    |---|---|---|---|
    | NOTE | note | Note | *(default)* |
    | IMPORTANT | note | Important | `star` |
    | TIP | tip | Tip | *(default)* |
    | HINT | tip | Hint | `question-circle` |
    | WARNING | caution | Warning | `warning` |
    | CAUTION | caution | Caution | *(default)* |
    | DANGER | danger | Danger | *(default)* |

  - **File trees:** inside an indented block, a bare root path ending in
    `/` followed by `├──`/`└──` branch lines becomes a Starlight
    `<FileTree>`. Multi-level nesting is supported via standard tree
    formatting (e.g. `│   ├──`).

  A page that ends up containing either component is written as `.mdx`
  with the needed import line; pages without either stay `.md`.

## Context & Sub-rules

Before taking action, read and follow the local, untracked instructions in
@AGENTS.local.md if that file exists. It holds machine- and maintainer-specific
rules that are not part of this repository. If it is absent, continue without it.
