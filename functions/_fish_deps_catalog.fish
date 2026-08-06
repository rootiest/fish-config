# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_catalog
#
# DESCRIPTION
#   Populates parallel global arrays (_fdc_bins, _fdc_tiers, _fdc_cargo,
#   _fdc_pm, _fdc_special) describing every managed shell dependency.
#   Must be called before accessing any _fdc_* array.
#
# EXAMPLE
#   _fish_deps_catalog
#   echo $_fdc_bins
function _fish_deps_catalog
    set -g _fdc_bins \
        uv cargo fish starship fzf zoxide direnv paru yay \
        wakatime tailscale \
        eza lsd bat btop dust duf prettyping ov rg lazygit lazydocker trash kitty wezterm python3 yt-dlp screen

    set -g _fdc_tiers \
        rec rec req rec req rec rec rec rec \
        int int \
        rec rec rec rec rec rec rec rec rec rec rec rec rec rec rec rec rec

    set -g _fdc_cargo \
        "" "" "" starship "" zoxide "" "" "" \
        "" "" \
        eza lsd bat "" du-dust "" "" ov ripgrep "" "" trashy "" "" "" "" ""

    set -g _fdc_pm \
        uv cargo fish starship fzf zoxide direnv "" yay \
        wakatime tailscale \
        eza lsd bat btop dust duf prettyping ov ripgrep lazygit lazydocker trash kitty wezterm python yt-dlp screen

    set -g _fdc_special \
        curl-uv rustup-installer git-cargo-fish curl-installer fzf-update "" "" paru-build yay-build \
        wakatime-binary "" \
        "" "" "" "" "" "" "" "" "" "" curl-lazydocker "" "" "" "" "" ""
end

# SYNOPSIS
#   _fish_deps_catalog_idx <bin>
#
# DESCRIPTION
#   Returns the 1-based index of a binary name in the _fdc_bins catalog array,
#   or an empty string if the binary is not found.
#
# ARGUMENTS
#   bin  The binary name to look up in the catalog
#
# EXIT STATUS
#   0  Binary found in the catalog
#   1  Binary not found
#
# RETURNS
#   The binary's 1-based catalog index, printed to stdout (nothing on failure)
#
# EXAMPLE
#   _fish_deps_catalog_idx fzf
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
