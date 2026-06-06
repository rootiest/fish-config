# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_install
#
# DESCRIPTION
#   Interactively installs each missing fish shell dependency from the catalog.
#   For each missing entry, prompts yes/no and the preferred install method
#   when multiple options are available.
#
# EXAMPLE
#   _fish_deps_install
function _fish_deps_install
    _fish_deps_catalog

    set -l pm (_fish_deps_detect_pm)
    set -l installed_any 0

    set -l i 1
    for bin in $_fdc_bins
        # Determine if this dep needs attention: missing, or fish < 4.0
        set -l needs_install 0
        set -l upgrade_label Install
        if not type -q $bin
            set needs_install 1
        else if test "$bin" = fish
            set -l _major (fish --version 2>&1 | string match -r 'version (\d+)')[2]
            if test -n "$_major"; and test "$_major" -lt 4
                set needs_install 1
                set upgrade_label "Upgrade"
            end
        end

        if test $needs_install -eq 1
            set -l cargo_crate  $_fdc_cargo[$i]
            set -l pm_pkg       $_fdc_pm[$i]
            set -l special      $_fdc_special[$i]

            # Build list of available install methods
            set -l methods
            set -l method_labels

            # Cargo — preferred for Rust tools; gets the latest crate version
            if test -n "$cargo_crate"
                if type -q cargo
                    set -a methods cargo
                    set -a method_labels "cargo ($cargo_crate)"
                else
                    set_color brblack
                    echo "  note: cargo not found — install cargo first for the latest $bin"
                    set_color normal
                end
            end

            # Preferred special methods — listed before system PM so they are the default
            switch $special
                case curl-uv
                    set -a methods special-uv
                    set -a method_labels "curl installer (official script)"
                case git-cargo-fish
                    if type -q cargo; and type -q uv
                        set -a methods special-git-cargo-fish
                        set -a method_labels "build from source (git + cargo)"
                    else
                        set_color brblack
                        set -l _need
                        type -q cargo; or set -a _need cargo
                        type -q uv; or set -a _need uv
                        echo "  note: "(string join " and " $_need)" not found — install them first to build fish from source"
                        set_color normal
                    end
                case rustup-installer
                    set -a methods special-rustup
                    set -a method_labels "rustup installer (curl | sh)"
                case curl-lazydocker
                    set -a methods special-lazydocker
                    set -a method_labels "curl installer (official script)"
                case wakatime-binary
                    set -a methods special-wakatime
                    set -a method_labels "binary download (github releases)"
            end

            # System PM — after cargo and preferred specials
            if test -n "$pm_pkg"; and test -n "$pm"
                set -a methods pm
                set -a method_labels "$pm ($pm_pkg)"
            end

            # Supplemental special methods (fallbacks, Arch-only, etc.)
            switch $special
                case fzf-update
                    set -a methods special-fzf
                    set -a method_labels "git clone (~/.fzf)"
                case fisher-bootstrap
                    set -a methods special-fisher
                    set -a method_labels "curl bootstrap (fisher)"
                case curl-installer
                    set -a methods special-curl
                    set -a method_labels "curl installer"
                case paru-build
                    # Only offered on Arch-based systems where pacman is present
                    if type -q yay
                        set -a methods special-yay-paru
                        set -a method_labels "yay -S paru"
                    end
                    if type -q pacman
                        set -a methods special-paru
                        set -a method_labels "build from AUR (makepkg)"
                    end
                case yay-build
                    if type -q paru
                        set -a methods special-paru-yay
                        set -a method_labels "paru -S yay"
                    end
                    if type -q pacman
                        set -a methods special-yay
                        set -a method_labels "build from AUR (makepkg)"
                    end
                case pipx
                    if type -q pipx
                        set -a methods special-pipx
                        set -a method_labels "pipx ($bin)"
                    else if type -q pip
                        set -a methods special-pip
                        set -a method_labels "pip install --user ($bin)"
                    end
            end

            if test (count $methods) -eq 0
                set_color yellow
                echo "  $bin: no install method available on this system — skipping"
                set_color normal
                set i (math $i + 1)
                continue
            end

            # Prompt: install/upgrade this dep?
            read -l -P (set_color cyan)"$upgrade_label $bin?"(set_color normal)" [Y/n] " _reply
            if test "$_reply" = n; or test "$_reply" = N
                set i (math $i + 1)
                continue
            end

            # Choose install method
            set -l chosen_method $methods[1]
            if test (count $methods) -gt 1
                echo "  Available methods:"
                set -l m 1
                for lbl in $method_labels
                    set_color brblack; echo -n "    $m) "; set_color normal
                    echo $lbl
                    set m (math $m + 1)
                end
                read -l -P "  Choose [1-"(count $methods)"] (default 1 = $method_labels[1]): " _choice
                if string match -qr '^\d+$' "$_choice"; and test "$_choice" -ge 1; and test "$_choice" -le (count $methods)
                    set chosen_method $methods[$_choice]
                end
            else
                set_color brblack; echo "  "(string lower $upgrade_label)"ing via $method_labels[1]"; set_color normal
            end

            # Execute chosen method
            switch $chosen_method
                case cargo
                    cargo install $cargo_crate
                case pm
                    _fish_deps_pm_install $pm_pkg
                case special-rustup
                    curl https://sh.rustup.rs -sSf | sh
                    # Add cargo to PATH for the rest of this session without restarting.
                    # Try CARGO_HOME first (set in config.fish), then the rustup default.
                    for _d in "$CARGO_HOME/bin" "$HOME/.cargo/bin"
                        if test -d "$_d"
                            fish_add_path "$_d"
                            break
                        end
                    end
                    if not type -q cargo
                        set_color yellow
                        echo "  cargo not yet in PATH — restart your shell if subsequent installs fail."
                        set_color normal
                    end
                case special-lazydocker
                    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
                case special-wakatime
                    set -l _arch (uname -m)
                    switch $_arch
                        case x86_64
                            set _arch amd64
                        case aarch64 arm64
                            set _arch arm64
                        case armv7l
                            set _arch arm
                        case '*'
                            set _arch amd64
                    end
                    set -l _zip "wakatime-cli-linux-$_arch.zip"
                    set -l _bin_src "wakatime-cli-linux-$_arch"
                    set -l _wt_dir "$HOME/.config/wakatime"
                    set -l _wt_bin "$_wt_dir/wakatime"
                    set -l _tmpdir (mktemp -d)
                    curl -L "https://github.com/wakatime/wakatime-cli/releases/latest/download/$_zip" \
                        -o "$_tmpdir/$_zip"
                    and unzip -o "$_tmpdir/$_zip" -d "$_tmpdir"
                    and mkdir -p "$_wt_dir" "$HOME/.local/bin"
                    and cp "$_tmpdir/$_bin_src" "$_wt_bin"
                    and chmod +x "$_wt_bin"
                    and ln -sf "$_wt_bin" "$HOME/.local/bin/wakatime"
                    rm -rf "$_tmpdir"
                case special-fzf
                    fzf-update
                case special-fisher
                    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
                    fisher update
                case special-curl
                    if test "$bin" = starship
                        curl -sS https://starship.rs/install.sh | sh
                    end
                case special-yay-paru
                    yay -S --noconfirm paru
                case special-paru-yay
                    paru -S --noconfirm yay
                case special-yay
                    set -l _build_dir (mktemp -d)
                    git clone https://aur.archlinux.org/yay.git $_build_dir
                    and pushd $_build_dir
                    and makepkg -si --noconfirm
                    and popd
                    rm -rf $_build_dir
                case special-paru
                    set -l _build_dir (mktemp -d)
                    git clone https://aur.archlinux.org/paru.git $_build_dir
                    and pushd $_build_dir
                    and makepkg -si --noconfirm
                    and popd
                    rm -rf $_build_dir
                case special-uv
                    curl -LsSf https://astral.sh/uv/install.sh | sh
                    # Add uv to PATH for the rest of this session
                    for _d in "$HOME/.local/bin" "$HOME/.cargo/bin"
                        if test -d "$_d"
                            fish_add_path "$_d"
                            break
                        end
                    end
                    if not type -q uv
                        set_color yellow
                        echo "  uv not yet in PATH — restart your shell if subsequent installs fail."
                        set_color normal
                    end
                case special-git-cargo-fish
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
                    test $_build_ok -eq 1
                case special-pipx
                    pipx install $bin
                case special-pip
                    pip install --user $bin
            end

            if test $status -eq 0
                set installed_any 1
                set_color green; echo "  $bin "(string lower $upgrade_label)"ed."; set_color normal
                if test "$bin" = fish
                    set_color yellow
                    echo "  Fish upgraded — restart your shell to use the new version."
                    set_color normal
                end
            else
                set_color red; echo "  $bin "(string lower $upgrade_label)" failed."; set_color normal
            end
        end
        set i (math $i + 1)
    end

    if test $installed_any -eq 0
        echo "Nothing to install."
    end
end
