import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

export const collections = {
  docs: defineCollection({
    loader: docsLoader(),
    schema: docsSchema({
      // z.strictObject (not z.object) so that Zod v4's default key-stripping
      // doesn't silently swallow typos in generated frontmatter — an unknown
      // key like `bogusField` must fail the build, not disappear quietly.
      extend: z.strictObject({
        // Include this page in the generated man page.
        man: z.boolean().default(true),
        // Publish this page to the website.
        site: z.boolean().default(true),
        // Verbatim heading text used by the man page renderer.
        manTitle: z.string().optional(),
        // Keywords resolving to this page via `help config <keyword>`.
        helpKeywords: z.array(z.string()).default([]),
      }),
    }),
  }),
};
