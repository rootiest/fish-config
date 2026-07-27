import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import sidebar from './src/sidebar.json' with { type: 'json' };

export default defineConfig({
  site: 'https://fish.rootiest.fyi',
  integrations: [
    starlight({
      title: 'Rootiest Fish Config',
      description: 'Reference manual for the rootiest fish configuration.',
      social: [
        {
          icon: 'code-branch',
          label: 'Gitea',
          href: 'https://git.rootiest.dev/rootiest/fish-config',
        },
      ],
      head: [
        {
          tag: 'script',
          content: 'document.addEventListener("DOMContentLoaded", () => { document.querySelectorAll("starlight-file-tree").forEach(tree => { tree.querySelectorAll("details").forEach((d, i) => { if (i !== 0) d.removeAttribute("open"); }); }); });',
        },
      ],
      customCss: ['./src/styles/catppuccin.css'],
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
    }),
  ],
});
