# fish-config docs site

[Starlight](https://starlight.astro.build) site for the
[fish-config](https://git.rootiest.dev/rootiest/fish-config) manual.

## Generated, not authored

Everything under `src/content/docs/` is generated — **do not edit it
directly**, changes will be overwritten. The sources are:

- `docs/manual/**` — prose for every section except the functions reference
- `functions/*.fish` comment headers — the functions reference (Section 5)

Regenerate from the repo root:

```fish title="regenerate the site content"
python3 docs/build-manual.py --site
```

`docs/verify-manual.py` validates both sources before you build; run it
first if you've touched a header or a manual page.

## Inline code spans

Function headers are read as plain text (by `config-help`, by `funcsave`,
by anyone opening the `.fish` file), so they're authored without backticks
— `-a/--all`, not `` `-a`/`--all` ``. `docs/codespans.py` puts the
backticks on at render time, as the last step of `prettify()`.

`build_concat()` runs the same pass, so the man page and `config-help`
mark code the way the site does rather than only where the SSOT happened
to backtick something by hand. `config-help` then renders those spans
bold and drops the delimiters, since a terminal pager would otherwise
show them as literal punctuation.

It recognises flags, `$vars`, `SCREAMING_SNAKE` env vars, snake_case
identifiers (`__fish_config_op_aliases`, `fish_greeting`), paths and
filenames, key chords (`Ctrl-R`), shadow chains (`ls->eza`), runs of tool
names (`btop, dust, duf, …`), whole command lines in a table column of
command lines, and command names it knows — the `_fdc_*` catalog in
`functions/_fish_deps_catalog.fish`, the `functions/` directory listing,
and a standard-command list in the module.

Names that also read as English (`find`, `top`, `screen`) are listed in
`AMBIGUOUS_COMMANDS` and are never wrapped on sight; they still count
where position already proves they're a command. Add to that list rather
than removing a rule if a wrap ever reads wrong.

Fenced blocks, indented blocks, existing code spans, headings, link
targets, URLs, component markup, and `<FileTree>` bodies are never
touched. Leaving a token alone is always the safe outcome, so every rule
bails out when it isn't sure.

Indented blocks matter only to the concat — `prettify()` has already
fenced them by the time the site is rendered — but there they are the
table of contents and every section 5 entry, which must stay verbatim.

## llms.txt

The [`starlight-llms-txt`](https://www.npmjs.com/package/starlight-llms-txt)
plugin emits `llms.txt`, `llms-full.txt`, and `llms-small.txt` alongside the
built pages — no configuration needed, it just walks the generated content.

## Icons

[`starlight-plugin-icons`](https://docs.rettend.me/starlight-plugin-icons)
+ [UnoCSS](https://unocss.dev) (`uno.config.ts`) render icons from any
[Iconify](https://icones.js.org) set as `i-<collection>:<name>` classes.
The Gitea link in the header uses it (see
`src/components/starlight/SocialIcons.astro`) to show the real Gitea logo
instead of Starlight's generic `code-branch` icon. Sidebar (`sidebar:
true`) and codeblock (`codeblock: true`) icon support are wired up in
`astro.config.mjs` but unused so far — see the plugin docs for the
`icon:` sidebar syntax if you want to add them.

## Development

```fish title="local dev server"
cd docs/site
npm install
npm run dev
```

## Deploy

Built and deployed to Cloudflare Pages by the Gitea Actions workflow on
every push to `main` — there's no manual deploy step.
