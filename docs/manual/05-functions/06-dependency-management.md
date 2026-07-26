---
title: Dependency Management
manTitle: 5.6 Dependency Management
sidebar:
  order: 6
helpKeywords:
- deps
---

## fish-deps

    Synopsis:  fish-deps [status|install|update|sync]
    Unified command for managing all tools this configuration depends on.

      status   (default) Show installed/missing status grouped by tier
      install  Interactively install each missing dependency
      update   Update all installed dependencies
      sync     Install missing deps, then update all

    Install method priority (highest to lowest):
      1. git+cargo source build (fish shell itself)
      2. cargo (Rust tools — gets latest crate version)
      3. system PM (paru/apt/brew/etc.)
      4. git clone (fzf)
      5. curl installer (starship, fisher, uv)

    When multiple methods are available you are prompted to choose.

    Dependencies are grouped into three tiers:

      Required      fish, fzf, zoxide
      Integrations  wakatime, tailscale
      Recommended   cargo, starship, uv, direnv, paru, yay, eza, lsd, bat,
                    btop, dust, duf, prettyping, ov, ripgrep, lazygit,
                    lazydocker, trash, kitty, wezterm, python3, yt-dlp

    fish-deps
    fish-deps install
    fish-deps update
    fish-deps sync

## check_fish_deps

    Synopsis:  check_fish_deps
    Backwards-compatibility alias for `fish-deps status`.

---
