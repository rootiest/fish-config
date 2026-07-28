---
title: Machine-local Configuration
---

Place machine-specific settings that should not be committed to git in:

    $__fish_user_dots_path/local.fish

`__fish_user_dots_path` defaults to `~/.config/.user-dots/fish`. Set a
custom location with:

    set -U __fish_user_dots_path /path/to/your/dots/fish

Typical uses: additional PATH entries, local aliases, hostname-specific env
vars, work-specific tool configs.

For convenience, a git-ignored `user-dots` symlink in the fish config
directory tracks `$__fish_user_dots_path` so the overlay can be browsed from
`~/.config/fish/`. It is created if missing and repointed if the path changes.
Opt out by setting `__fish_user_dots_symlink` to a falsy value, or toggling
"Dots link" off on the config-settings Paths page — this stops generation and
removes any existing link. It only ever manages a symlink and never clobbers a
real file or directory at that path.

