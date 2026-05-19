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
        if test "$bin" = fisher; or not type -q $bin
            set i (math $i + 1)
            continue
        end

        set -l cargo_crate  $_fdc_cargo[$i]
        set -l pm_pkg       $_fdc_pm[$i]
        set -l special      $_fdc_special[$i]

        # cargo: update via rustup
        if test "$special" = rustup-installer
            if type -q rustup
                echo "Updating $bin..."
                rustup update
                set updated_any 1
            end
            set i (math $i + 1)
            continue
        end

        # fzf: always use fzf-update (git-based)
        if test "$special" = fzf-update
            echo "Updating $bin..."
            fzf-update
            set updated_any 1
            set i (math $i + 1)
            continue
        end

        # lazydocker: re-run the official install/update script
        if test "$special" = curl-lazydocker
            echo "Updating $bin..."
            curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
            set updated_any 1
            set i (math $i + 1)
            continue
        end

        # wakatime: re-download the binary from github releases
        if test "$special" = wakatime-binary
            echo "Updating $bin..."
            set -l _arch (uname -m)
            switch $_arch
                case x86_64;  set _arch amd64
                case aarch64 arm64; set _arch arm64
                case armv7l;  set _arch arm
                case '*';     set _arch amd64
            end
            set -l _zip "wakatime-cli-linux-$_arch.zip"
            set -l _bin_src "wakatime-cli-linux-$_arch"
            set -l _wt_bin "$HOME/.config/wakatime/wakatime"
            set -l _tmpdir (mktemp -d)
            curl -L "https://github.com/wakatime/wakatime-cli/releases/latest/download/$_zip" \
                -o "$_tmpdir/$_zip"
            and unzip -o "$_tmpdir/$_zip" -d "$_tmpdir"
            and cp "$_tmpdir/$_bin_src" "$_wt_bin"
            and chmod +x "$_wt_bin"
            rm -rf "$_tmpdir"
            and set updated_any 1
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

        # uv: use built-in self-updater
        if test "$special" = curl-uv
            echo "Updating $bin..."
            uv self update
            set updated_any 1
            set i (math $i + 1)
            continue
        end

        # fish: prefer build from source via git + cargo; fall back to PM
        if test "$special" = git-cargo-fish
            if type -q cargo; and type -q uv
                echo "Updating $bin..."
                set -l _tmpdir (mktemp -d)
                set -l _build_ok 0
                git clone https://github.com/fish-shell/fish-shell "$_tmpdir"
                and begin
                    set -l _tag (git -C "$_tmpdir" tag --list 'fish-*' --sort=version:refname | tail -1)
                    test -n "$_tag"; and git -C "$_tmpdir" checkout "$_tag"
                    true
                end
                and pushd "$_tmpdir"
                and uv run --no-managed-python cargo install --path .
                and set _build_ok 1
                popd 2>/dev/null
                rm -rf "$_tmpdir"
                if test $_build_ok -eq 1
                    set updated_any 1
                    set_color yellow
                    echo "  Fish updated — restart your shell to use the new version."
                    set_color normal
                end
            else if test -n "$pm_pkg"; and test -n "$pm"
                echo "Updating $bin (cargo/uv unavailable, using system PM)..."
                _fish_deps_pm_upgrade $pm_pkg
                set updated_any 1
                set_color yellow
                echo "  Fish updated — restart your shell to use the new version."
                set_color normal
            else
                set_color yellow
                echo "  fish: cannot update — install cargo and uv to build from source"
                set_color normal
            end
            set i (math $i + 1)
            continue
        end

        # curl-installer tools (starship etc.): re-run install script, which upgrades in place
        if test "$special" = curl-installer
            if test "$bin" = starship
                echo "Updating $bin..."
                curl -sS https://starship.rs/install.sh | sh -s -- --yes
                set updated_any 1
            end
            set i (math $i + 1)
            continue
        end

        # Cargo: prefer for Rust tools
        if test -n "$cargo_crate"; and type -q cargo
            echo "Updating $bin..."
            cargo install --force $cargo_crate
            set updated_any 1
            set i (math $i + 1)
            continue
        end

        # System PM fallback
        if test -n "$pm_pkg"; and test -n "$pm"
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
