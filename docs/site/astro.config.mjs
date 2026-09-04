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
