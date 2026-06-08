# 6. DEPENDENCY CATALOG

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | **6. Dependency Catalog** | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Installation](9-installation.md) | [10. Personalization](10-personalization.md) | [11. Viewing This Manual](11-viewing-this-manual.md)

---

fish-deps manages these tools. Run `fish-deps` to check status, or
`fish-deps install` to install missing ones.

## Required

    uv        Python package manager (Astral)
    cargo     Rust toolchain (via rustup)
    fish      Fish shell >= 4.0
    fisher    Fish plugin manager
    starship  Cross-shell prompt
    fzf       Fuzzy finder
    zoxide    Smart cd with frecency
    direnv    Per-directory environment loading
    paru      AUR helper (Arch only; preferred)
    yay       AUR helper (Arch only; fallback)

## Integrations

    wakatime   Developer time tracking
    tailscale  Mesh VPN client

## Recommended

    eza         Modern ls replacement
    lsd         ls replacement (fallback to eza)
    bat         Syntax-highlighted cat
    btop        Modern resource monitor
    dust        Disk usage tree (Rust)
    duf         Disk usage/free overview
    prettyping  Colorized ping wrapper
    ov          Modern pager (replaces less)
    ripgrep     Fast line search
    lazygit     Terminal git UI
    lazydocker  Terminal docker UI
    trash       Safe delete (trash-cli)
    kitty       GPU-accelerated terminal (primary)
    wezterm     GPU-accelerated terminal (alternative)

## Install Methods

The install priority for each tool:

    cargo     Rust tools (eza, lsd, bat, dust, ov, ripgrep, trashy, zoxide,
              starship) — always gets the latest crate version
    system PM paru / apt / brew / dnf / etc. — for tools without a crate
    git clone fzf — installed from GitHub to ~/.fzf/
    curl      starship installer, fisher bootstrap, uv installer
    pipx      Python-based tools

---
