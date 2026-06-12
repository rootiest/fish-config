# 6. DEPENDENCY CATALOG

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | **6. Dependency Catalog** | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Installation](9-installation.md) | [10. Personalization](10-personalization.md) | [11. Viewing This Manual](11-viewing-this-manual.md)

---

fish-deps manages these tools. Run `fish-deps` to check status, or
`fish-deps install` to install missing ones.

## Required

    fish      Fish shell >= 4.0
    fzf       Fuzzy finder
    zoxide    Smart cd with frecency

## Integrations

    wakatime   Developer time tracking
    tailscale  Mesh VPN client

## Recommended

    cargo       Rust toolchain (via rustup); used by fish-deps to install
                Rust-based tools and to build fish from source. All paths
                are gated on type -q cargo and degrade gracefully.
    starship    Cross-shell prompt; loaded via type -q starship guard.
                Without it the Catppuccin nim-style fallback prompt activates.
    uv          Python package and project manager (Astral); used by the
                fish-from-source build path in fish-deps. All consumers
                degrade gracefully without it.
    direnv      Per-directory environment loading; integration is fully
                guarded with type -q direnv. Without it the direnv hook
                is simply not loaded and auto-venv activates normally.
    paru        AUR helper (Arch only; preferred); guarded throughout —
                non-Arch systems silently skip AUR-specific paths.
    yay         AUR helper (Arch only; fallback to paru); same guards apply.
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
    python3     Standalone interpreter — used by the AI session helpers
                (save_claude_session / save_antigravity_session) and the
                paru/yay log cleaner. Note: uv does not provide python3 on
                PATH, and Arch's base does not include it, so it is listed
                separately. All consumers degrade gracefully without it.

## Install Methods

The install priority for each tool:

    cargo     Rust tools (eza, lsd, bat, dust, ov, ripgrep, trashy, zoxide,
              starship) — always gets the latest crate version
    system PM paru / apt / brew / dnf / etc. — for tools without a crate
    git clone fzf — installed from GitHub to ~/.fzf/
    curl      starship installer, fisher bootstrap, uv installer

---
