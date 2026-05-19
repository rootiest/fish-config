# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Interactively install missing deps.
# For each missing dep: prompts yes/no, then prompts install method when multiple exist.
function _fish_deps_install
    _fish_deps_catalog

    set -l pm (_fish_deps_detect_pm)
    set -l installed_any 0

    set -l i 1
    for bin in $_fdc_bins
        if not type -q $bin
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

            # rustup installer — listed before system PM so it is the default for cargo itself
            if test "$special" = rustup-installer
                set -a methods special-rustup
                set -a method_labels "rustup installer (curl | sh)"
            end

            # System PM — after cargo/rustup so those are always the default when available
            if test -n "$pm_pkg"; and test -n "$pm"
                set -a methods pm
                set -a method_labels "$pm ($pm_pkg)"
            end

            # Remaining special methods
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

            # Prompt: install this dep?
            read -l -P (set_color cyan)"Install $bin?"(set_color normal)" [Y/n] " _reply
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
                if test -n "$_choice"; and test "$_choice" -ge 1; and test "$_choice" -le (count $methods)
                    set chosen_method $methods[$_choice]
                end
            else
                set_color brblack; echo "  Installing via $method_labels[1]"; set_color normal
            end

            # Execute chosen method
            switch $chosen_method
                case cargo
                    cargo install $cargo_crate
                case pm
                    _fish_deps_pm_install $pm_pkg
                case special-rustup
                    curl https://sh.rustup.rs -sSf | sh
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
                case special-paru
                    set -l _build_dir (mktemp -d)
                    git clone https://aur.archlinux.org/paru.git $_build_dir
                    and pushd $_build_dir
                    and makepkg -si --noconfirm
                    and popd
                    rm -rf $_build_dir
                case special-pipx
                    pipx install $bin
                case special-pip
                    pip install --user $bin
            end

            if test $status -eq 0
                set installed_any 1
                set_color green; echo "  $bin installed."; set_color normal
            else
                set_color red; echo "  $bin install failed."; set_color normal
            end
        end
        set i (math $i + 1)
    end

    if test $installed_any -eq 0
        echo "Nothing to install."
    end
end
