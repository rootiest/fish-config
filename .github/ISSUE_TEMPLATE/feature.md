---
name: Feature or enhancement request
about: Propose new functionality, or an improvement to something that already exists
labels:
  - Kind/Feature
---

<!--
  Title this as a plain description of what you want, NOT as a
  conventional-commit subject:

      A picker for switching themes without editing config.fish

  not `feat(theme): add theme picker`. That format belongs on the PR that
  implements this; here, the Kind/ and Area/ labels carry type and scope.
  See CONTRIBUTING.md § Labels.

  This template applies Kind/Feature. If you're proposing an improvement to
  something that already exists rather than genuinely new functionality, say
  so in the Summary — a maintainer will swap the label to Kind/Enhancement
  at triage. Contributors without push access can't set labels directly.

  Keep every heading below except Alternatives considered and Notes, which
  you can drop if they'd be empty. Delete these comments as you go.
-->

## Summary

<!--
  What you want, in one or two sentences. Lead with the capability, not the
  implementation — "a way to preview a theme before committing to it" rather
  than "add a --preview flag to theme-set".
-->

## Problem

<!--
  What's awkward, slow, or impossible today. Be concrete about the situation
  that led you here: the sequence of commands you run now, what you have to
  remember, or what goes wrong. A proposal is only as good as the problem it
  names, and this section is what a reviewer weighs the cost against.
-->

## Proposed behavior

<!--
  The concrete shape of the thing. Where they apply:

  - The command or function name, and its flags.
  - What it prints on success, and what it does on the error paths.
  - What happens with no arguments, or with a missing dependency.
  - Whether it's interactive, and what it falls back to when it isn't.

  A short usage sketch in a ```fish block is worth several paragraphs.
-->

## Alternatives considered

<!--
  Other approaches you weighed and why you set them aside — including
  "solve it in my own ~/.config/.user-dots/fish/local.fish instead", which is
  the right answer for anything genuinely specific to one machine or one
  person's taste. See CONTRIBUTING.md § Secrets & Machine-Specific Config.

  Drop this heading if there were no real alternatives.
-->

## Scope

<!--
  Answer these — they determine how the change has to be built, and getting
  them wrong late is expensive:

  - Does this shadow a builtin or an existing command?
  - Does it run at startup, or bind a key, or set an environment variable?
  - Does it need a new external dependency, and what should happen when that
    dependency is missing?
  - Is it opinionated enough that users should be able to turn it off? If any
    of the above is yes, it likely needs a `# COMPONENT` header and an
    `__fish_config_op_enabled` guard — see CONTRIBUTING.md § Opinionated
    Components.
  - Does it need a manual entry (a `# CATEGORY` header), and under which of
    the docs/manual/05-functions/ categories?
-->

## Acceptance criteria

<!--
  What must be true for this issue to close, as a checkbox list. This is the
  issue-side counterpart to a PR's ## Verification: it's the shared
  definition of done, agreed before the work starts rather than argued about
  after.

  - One observable outcome per line — behavior a reader could check, not
    implementation steps.
  - Cover the error and fallback paths, not just the happy one.
  - Include the docs and tests the change will owe.

  Leave the boxes unchecked; they get ticked as the work lands.
-->

- [ ] 
- [ ] 

## Notes

<!--
  Anything else: prior art in other shells or dotfiles, links to the relevant
  upstream tool's docs, related issues (`Refs #42`). Drop this heading if
  there's nothing to add.
-->
