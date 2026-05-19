# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Populates parallel arrays describing every managed dependency.
# Callers must invoke this function before accessing _fdc_* variables.
#
# Array layout (same index across all sets):
#   _fdc_bins    — binary name (what `type -q` checks)
#   _fdc_tiers   — req | int | rec
#   _fdc_cargo   — cargo crate name, or "" if not on crates.io
#   _fdc_pm      — system PM package name, or "" if not in repos
#   _fdc_special — special install key: fisher-bootstrap | fzf-update |
#                  paru-build | pipx | curl-installer | "" (none)
function _fish_deps_catalog
    set -g _fdc_bins \
        fish fisher starship fzf zoxide direnv paru \
        wakatime tailscale \
        eza lsd bat btop dust duf prettyping most rg lazygit lazydocker trash kitty wezterm

    set -g _fdc_tiers \
        req req req req req req req \
        int int \
        rec rec rec rec rec rec rec rec rec rec rec rec rec rec

    set -g _fdc_cargo \
        "" "" starship "" zoxide "" "" \
        "" "" \
        eza lsd bat "" du-dust "" "" "" ripgrep "" "" trash-cli "" ""

    set -g _fdc_pm \
        fish "" starship fzf zoxide direnv paru \
        wakatime tailscale \
        eza lsd bat btop dust duf prettyping most ripgrep lazygit lazydocker trash kitty wezterm

    set -g _fdc_special \
        "" fisher-bootstrap curl-installer fzf-update "" "" paru-build \
        pipx "" \
        "" "" "" "" "" "" "" "" "" "" "" "" "" ""
end

# Returns the index (1-based) of $argv[1] in the catalog, or "" if not found.
function _fish_deps_catalog_idx --argument-names bin
    _fish_deps_catalog
    set -l i 1
    for b in $_fdc_bins
        if test "$b" = "$bin"
            echo $i
            return
        end
        set i (math $i + 1)
    end
end
