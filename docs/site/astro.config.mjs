import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import sidebar from './src/sidebar.json' with { type: 'json' };

export default defineConfig({
  site: 'https://fish-config-docs.pages.dev',
  integrations: [
    starlight({
      title: 'Fish Config',
      description: 'Reference manual for the rootiest fish configuration.',
      social: [
        {
          icon: 'code-branch',
          label: 'Gitea',
          href: 'https://git.rootiest.dev/rootiest/fish-config',
        },
      ],
      customCss: ['./src/styles/catppuccin.css'],
      sidebar,
    }),
  ],
});
