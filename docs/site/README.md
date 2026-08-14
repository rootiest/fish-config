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

## llms.txt

The [`starlight-llms-txt`](https://www.npmjs.com/package/starlight-llms-txt)
plugin emits `llms.txt`, `llms-full.txt`, and `llms-small.txt` alongside the
built pages — no configuration needed, it just walks the generated content.

## Development

```fish title="local dev server"
cd docs/site
npm install
npm run dev
```

## Deploy

Built and deployed to Cloudflare Pages by the Gitea Actions workflow on
every push to `main` — there's no manual deploy step.
