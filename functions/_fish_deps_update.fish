# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Update all installed deps using their known install method.
# Priority: cargo > system PM > special (fzf-update, fisher, pipx).
function _fish_deps_update
    _fish_deps_catalog

    set -l pm (_fish_deps_detect_pm)
    set -l updated_any 0

    # Fisher plugins — always update if fisher is present
    if type -q fisher
        echo "Updating fisher plugins..."
        fisher update
        set updated_any 1
    end

    set -l i 1
    for bin in $_fdc_bins
        # Skip fisher itself (handled above) and tools that aren't installed
        if test "$bin" = fisher -o not (type -q $bin)
            set i (math $i + 1)
            continue
        end

        set -l cargo_crate  $_fdc_cargo[$i]
        set -l pm_pkg       $_fdc_pm[$i]
        set -l special      $_fdc_special[$i]

        # fzf: always use fzf-update (git-based)
        if test "$special" = fzf-update
            echo "Updating $bin..."
            fzf-update
            set updated_any 1
            set i (math $i + 1)
            continue
        end

        # pipx tools
        if test "$special" = pipx
            if type -q pipx
                echo "Updating $bin..."
                pipx upgrade $bin
                set updated_any 1
            end
            set i (math $i + 1)
            continue
        end

        # curl-installer tools (starship etc.): re-run install script, which upgrades in place
        if test "$special" = curl-installer
            if test "$bin" = starship
                echo "Updating $bin..."
                curl -sS https://starship.rs/install.sh | sh -- --yes
                set updated_any 1
            end
            set i (math $i + 1)
            continue
        end

        # Cargo: prefer for Rust tools
        if test -n "$cargo_crate" -a (type -q cargo)
            echo "Updating $bin..."
            cargo install --force $cargo_crate
            set updated_any 1
            set i (math $i + 1)
            continue
        end

        # System PM fallback
        if test -n "$pm_pkg" -a -n "$pm"
            echo "Updating $bin..."
            _fish_deps_pm_upgrade $pm_pkg
            set updated_any 1
        end

        set i (math $i + 1)
    end

    if test $updated_any -eq 0
        echo "Nothing to update."
    end
end
