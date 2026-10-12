import { defineConfig } from 'astro/config';
import UnoCSS from 'unocss/astro';
import Icons from 'starlight-plugin-icons';
import starlightLinksValidator from 'starlight-links-validator';
import starlightCatppuccin from '@catppuccin/starlight';
import starlightLlmsTxt from 'starlight-llms-txt';
import sidebar from './src/sidebar.json' with { type: 'json' };

export default defineConfig({
  prerenderConflictBehavior: 'ignore',
  site: 'https://fish.rootiest.fyi',
  // Sections 12-18 moved down one when "12. Function Templates" was added;
  // keep the old URLs working (checked by docs/verify-manual.py).
  redirects: {
    '/12-troubleshooting': '/13-troubleshooting/',
    '/13-viewing-this-manual': '/14-viewing-this-manual/',
    '/14-testing': '/15-testing/',
    '/15-contributing': '/16-contributing/',
    '/16-agent-tooling': '/17-agent-tooling/',
    '/17-attribution': '/18-attribution/',
    '/18-license': '/19-license/',
  },
  integrations: [
    UnoCSS(),
    ...Icons({
      sidebar: true,
      codeblock: true,
      extractSafelist: true,
      starlight: {
        title: 'Rootiest Fish Config',
        description: 'Reference manual for the rootiest fish configuration.',
        favicon: '/favicon.svg',
        logo: {
          src: './src/assets/logo.svg',
        },
        social: [
          {
            icon: 'code-branch',
            label: 'Gitea',
            href: 'https://git.rootiest.dev/rootiest/fish-config',
          },
          {
            icon: 'github',
            label: 'GitHub',
            href: 'https://github.com/rootiest/fish-config',
          },
        ],
        components: {
          SocialIcons: './src/components/starlight/SocialIcons.astro',
        },
        head: [
          {
            tag: 'script',
            content: 'document.addEventListener("DOMContentLoaded", () => { document.querySelectorAll("starlight-file-tree").forEach(tree => { tree.querySelectorAll("details").forEach((d, i) => { if (i !== 0) d.removeAttribute("open"); }); }); });',
          },
        ],
        plugins: [
          starlightLinksValidator(),
          starlightCatppuccin({
            dark: { flavor: "mocha", accent: "green" },
            light: { flavor: "latte", accent: "sky" },
          }),
          starlightLlmsTxt(),
        ],
        expressiveCode: {
          // Shiki ships both Catppuccin flavours; Starlight picks by the
          // reader's colour scheme, matching the palette in catppuccin.css.
          themes: ['catppuccin-mocha', 'catppuccin-latte'],
          styleOverrides: {
            borderRadius: '0.4rem',
            borderColor: 'var(--sl-color-gray-5)',
            codeFontSize: '0.875rem',
          },
        },
        sidebar,
      },
    }),
  ],
});
