# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm,cat), destructive, network, blocking-prompt
#
# SYNOPSIS
#   _fish_deps_install
#
# DESCRIPTION
#   Interactively installs each missing fish shell dependency from the catalog.
#   For each missing entry, prompts yes/no/quit and the preferred install
#   method when multiple options are available.
#
#   Answer q at any prompt, or press Ctrl+C or Ctrl+D, to stop the whole run:
#   nothing further is offered or installed. Some installers (cargo, apt)
#   handle Ctrl+C themselves and exit normally instead of dying; those are
#   recognized by their exit status, so one Ctrl+C is enough.
#
#   Optional-tier and Terminal-Emulator-tier dependencies are skipped by
#   default; pass --optional / --terminals to include them individually, or
#   --all to include both.
#
#   The paru and yay AUR helpers are only offered on Arch-based systems.
#
#   Prerequisites the installers assume are offered when a chosen method
#   needs them, never before you have said yes to the tool itself:
#
#     C compiler    Before any cargo install (cc is the linker).
#     Rust toolchain  When cargo is a rustup shim with no default toolchain.
#     unzip         Before the wakatime-cli binary download.
#     Go            Before go install of ov, where the distro has no ov.
#
#   Every crates.io install passes --locked, so cargo builds against the
#   dependency versions the crate was published with rather than whatever is
#   newest. Without it, eza 0.23.5 fails to compile against a newer
#   palette release.
#
# ARGUMENTS
#   --optional   Also offer to install Optional-tier dependencies
#   --terminals  Also offer to install Terminal-Emulator-tier dependencies
#   --all        Shorthand for --optional --terminals
#
# EXIT STATUS
#   0    Nothing failed (including a run where everything was declined)
#   1    One or more installs failed
#   130  The run was cancelled (q, Ctrl+C or Ctrl+D)
#
# EXAMPLE
#   _fish_deps_install
#   _fish_deps_install --optional
#   _fish_deps_install --terminals
#   _fish_deps_install --all
function _fish_deps_install
    _fish_deps_catalog

    set -l include_optional 0
    set -l include_terminals 0
    if contains -- --all $argv
        set include_optional 1
        set include_terminals 1
    end
    if contains -- --optional $argv
        set include_optional 1
    end
    if contains -- --terminals $argv
        set include_terminals 1
    end

    __fish_palette

    set -l pm (_fish_deps_detect_pm)
    set -l installed_any 0
    set -l failed
    set -l skipped_optional 0
    set -l skipped_terminals 0
    set -l cancelled 0

    # Cancellation. `read` failing (Ctrl+C / Ctrl+D) and `q` are handled where
    # the prompts are; this covers a SIGINT delivered to fish itself while a
    # step runs. _fdc_active scopes the handler to this run, and the handler
    # removes itself if it is ever left behind by an aborted one.
    set -g _fdc_cancelled 0
    set -g _fdc_active 1
    for _need in cc toolchain unzip go
        set -e _fdc_ensure_$_need
    end
    function __fdi_on_sigint --on-signal SIGINT
        if set -q _fdc_active
            set -g _fdc_cancelled 1
        else
            functions -e __fdi_on_sigint
        end
    end

    set -l i 1
    for bin in $_fdc_bins
        # win32yank only matters under WSL2 — skip the entry entirely
        # elsewhere so a plain Linux box never sees it, not even as a
        # "no install method available" note.
        if test "$bin" = win32yank.exe; and not string match -qi '*microsoft*' (cat /proc/sys/kernel/osrelease 2>/dev/null)
            set i (math $i + 1)
            continue
        end

        # The AUR helpers exist only on Arch-based systems. Elsewhere there
        # is nothing to install, so skip them as silently as win32yank.
        if contains -- $bin paru yay; and not _fish_deps_is_arch
            set i (math $i + 1)
            continue
        end

        # Optional-tier deps are opt-in: skip unless --optional/--all was passed.
        if test "$_fdc_tiers[$i]" = opt; and test $include_optional -eq 0
            if not command -q $bin
                set skipped_optional (math $skipped_optional + 1)
            end
            set i (math $i + 1)
            continue
        end

        # Terminal-emulator-tier deps are opt-in: skip unless --terminals/--all was passed.
        if test "$_fdc_tiers[$i]" = term; and test $include_terminals -eq 0
            if not command -q $bin
                set skipped_terminals (math $skipped_terminals + 1)
            end
            set i (math $i + 1)
            continue
        end

        # Determine if this dep needs attention: missing, or fish < 4.0
        set -l needs_install 0
        set -l upgrade_label Install
        # Past tense is its own word: appending "ed" to the label gave
        # "upgradeed".
        set -l done_word installed
        # command -q (not type -q): a wrapper function shadowing the name
        # (rg, rm, yt-dlp) must not be mistaken for the installed binary.
        if not command -q $bin
            set needs_install 1
        else if test "$bin" = fish
            set -l _major (fish --version 2>&1 | string match -r 'version (\d+)')[2]
            if test -n "$_major"; and test "$_major" -lt 4
                set needs_install 1
                set upgrade_label Upgrade
                set done_word upgraded
            end
        end

        if test $needs_install -eq 1
            set -l cargo_crate $_fdc_cargo[$i]
            set -l pm_pkg $_fdc_pm[$i]
            set -l special $_fdc_special[$i]

            # The catalog spells packages the Arch way. Translate to this
            # manager's name, and drop the method when its index has no such
            # package (apt has no ov), instead of offering it only to fail.
            set -l pm_missing 0
            if test -n "$pm_pkg"; and test -n "$pm"
                set pm_pkg (_fish_deps_pm_pkg $pm $pm_pkg)
                if test -z "$pm_pkg"; or not _fish_deps_pm_has_pkg $pm $pm_pkg
                    set pm_missing 1
                    set pm_pkg ""
                end
            end

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
                    set -a method_labels "rustup installer (official script)"
                case curl-lazydocker
                    set -a methods special-lazydocker
                    set -a method_labels "curl installer (official script)"
                case wakatime-binary
                    set -a methods special-wakatime
                    set -a method_labels "binary download (github releases)"
                case marktext-release
                    # Upstream packages MarkText for the AUR and for its own
                    # GitHub releases only -- no distro carries it under a
                    # common name, so off Arch the AppImage is the only
                    # option and $_fdc_pm is deliberately empty.
                    if type -q paru
                        set -a methods special-marktext-paru
                        set -a method_labels "paru -S marktext-bin (AUR)"
                    else if type -q yay
                        set -a methods special-marktext-yay
                        set -a method_labels "yay -S marktext-bin (AUR)"
                    end
                    set -a methods special-marktext-appimage
                    set -a method_labels "AppImage download (~/.local/bin/marktext)"
                case win32yank-release
                    if test (uname -m) = x86_64
                        set -a methods special-win32yank
                        set -a method_labels "binary download (github releases)"
                    else
                        set_color brblack
                        echo "  note: win32yank only ships x86_64 builds (this is "(uname -m)")"
                        set_color normal
                    end
                case go-ov
                    if type -q go
                        set -a methods special-go-ov
                        set -a method_labels "go install (github.com/noborus/ov@latest)"
                    else if test -z "$pm_pkg"
                        # No system package either, so Go is the only way to
                        # get ov here: offer it, and fetch Go when chosen.
                        set -a methods special-go-ov
                        set -a method_labels "go install (github.com/noborus/ov@latest; installs Go first)"
                    else
                        set_color brblack
                        echo "  note: go not found — install go first for the latest $bin (the system package may be older)"
                        set_color normal
                    end
            end

            # System PM — after cargo and preferred specials
            if test -n "$pm_pkg"; and test -n "$pm"
                set -a methods pm
                set -a method_labels "$pm ($pm_pkg)"
            else if test $pm_missing -eq 1
                set_color brblack
                echo "  note: $bin is not packaged for $pm on this system"
                set_color normal
            end

            # Supplemental special methods (fallbacks, Arch-only, etc.)
            switch $special
                case fzf-update
                    set -a methods special-fzf
                    set -a method_labels "git clone (~/.fzf)"
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
            end

            if test (count $methods) -eq 0
                set_color yellow
                echo "  $bin: no install method available on this system — skipping"
                set_color normal
                set i (math $i + 1)
                continue
            end

            # Prompt: install/upgrade this dep?
            _fish_deps_ask "$upgrade_label $bin?"
            switch $status
                case 1
                    set i (math $i + 1)
                    continue
                case 2
                    set cancelled 1
                    break
            end

            # Choose install method
            set -l chosen_method $methods[1]
            if test (count $methods) -gt 1
                echo "  Available methods:"
                set -l m 1
                for lbl in $method_labels
                    set_color brblack
                    echo -n "    $m) "
                    set_color normal
                    echo $lbl
                    set m (math $m + 1)
                end
                read -l -P "  Choose [1-"(count $methods)", q to quit] (default 1 = $method_labels[1]): " _choice
                or begin
                    # EOF (Ctrl+D) or Ctrl+C: not a choice of the default.
                    set cancelled 1
                    break
                end
                if string match -qir '^q(uit)?$' -- "$_choice"
                    set cancelled 1
                    break
                end
                if string match -qr '^\d+$' "$_choice"; and test "$_choice" -ge 1; and test "$_choice" -le (count $methods)
                    set chosen_method $methods[$_choice]
                end
            else
                set_color brblack
                echo "  "(string lower $upgrade_label)"ing via $method_labels[1]"
                set_color normal
            end

            # Execute chosen method
            switch $chosen_method
                case cargo
                    # --locked: build against the dependency versions the
                    # crate was published with. Unlocked, eza 0.23.5 breaks on
                    # a newer palette release.
                    _fish_deps_ensure cargo
                    set -l _pre $status
                    test $_pre -eq 130; and set cancelled 1
                    test $_pre -eq 0; and cargo install --locked $cargo_crate
                case pm
                    _fish_deps_pm_install $pm_pkg
                case special-rustup
                    _fish_deps_run_script https://sh.rustup.rs sh
                    set -l _rustup_status $status
                    # Put cargo on PATH for the rest of this session, so no
                    # restart is needed. Both candidates are added: rustup
                    # installs under CARGO_HOME when it is exported and under
                    # ~/.cargo otherwise, and `cargo install` writes to
                    # CARGO_HOME either way.
                    _fish_deps_refresh_path
                    set -e _fdc_ensure_toolchain _fdc_ensure_cc
                    if test $_rustup_status -eq 0; and not type -q cargo
                        set_color yellow
                        echo "  cargo not yet in PATH — restart your shell if subsequent installs fail."
                        set_color normal
                    end
                    test $_rustup_status -eq 0
                case special-go-ov
                    _fish_deps_ensure go
                    set -l _pre $status
                    test $_pre -eq 130; and set cancelled 1
                    if test $_pre -eq 0
                        go install github.com/noborus/ov@latest
                        set -l _go_status $status
                        # go install places binaries in $GOBIN, falling back
                        # to $GOPATH/bin (default ~/go/bin); the helper asks
                        # go itself, since GOPATH may be customized.
                        _fish_deps_refresh_path
                        if test $_go_status -eq 0; and not type -q ov
                            set_color yellow
                            echo "  ov not yet in PATH — restart your shell if subsequent installs fail."
                            set_color normal
                        end
                        test $_go_status -eq 0
                    else
                        false
                    end
                case special-lazydocker
                    _fish_deps_run_script https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh bash
                case special-marktext-paru
                    paru -S --noconfirm marktext-bin
                case special-marktext-yay
                    yay -S --noconfirm marktext-bin
                case special-marktext-appimage
                    _fish_deps_marktext_appimage
                case special-wakatime
                    # The release is a zip; a minimal server has no unzip.
                    _fish_deps_ensure unzip
                    set -l _pre $status
                    test $_pre -eq 130; and set cancelled 1
                    test $_pre -eq 0; and _fish_deps_wakatime_binary
                case special-win32yank
                    _fish_deps_win32yank_binary
                case special-fzf
                    fzf-update
                case special-curl
                    if test "$bin" = starship
                        _fish_deps_run_script https://starship.rs/install.sh sh
                    else
                        false
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
                    _fish_deps_run_script https://astral.sh/uv/install.sh sh
                    set -l _uv_status $status
                    # Add uv to PATH for the rest of this session
                    _fish_deps_refresh_path
                    if test $_uv_status -eq 0; and not type -q uv
                        set_color yellow
                        echo "  uv not yet in PATH — restart your shell if subsequent installs fail."
                        set_color normal
                    end
                    test $_uv_status -eq 0
                case special-git-cargo-fish
                    _fish_deps_ensure cargo
                    set -l _pre $status
                    test $_pre -eq 130; and set cancelled 1
                    test $_pre -eq 0; and _fish_deps_build_fish
            end
            set -l _rc $status

            # An installer that traps SIGINT exits with 128+2 instead of dying
            # of the signal, so fish carries on as if it had merely failed.
            # Treat that, and a SIGINT fish took itself, as a cancellation:
            # nothing further is offered.
            test $_rc -eq 130; and set cancelled 1
            test "$_fdc_cancelled" = 1; and set cancelled 1
            if test $cancelled -eq 1
                break
            end

            if test $_rc -eq 0
                set installed_any 1
                set_color green
                echo "  $bin $done_word."
                set_color normal
                if test "$bin" = fish
                    set_color yellow
                    echo "  Fish upgraded — restart your shell to use the new version."
                    set_color normal
                end
            else
                set -a failed $bin
                set_color red
                echo "  $bin "(string lower $upgrade_label)" failed."
                set_color normal
            end
        end
        set i (math $i + 1)
    end

    # Tear the cancellation machinery down on every path out, so a finished
    # run leaves no handler or flag in the user's shell.
    set -l interrupted $cancelled
    functions -e __fdi_on_sigint
    set -e _fdc_active
    set -e _fdc_cancelled

    if test $interrupted -eq 1
        echo "$c_warn""Installation cancelled — nothing further was installed.$c_reset" >&2
        return 130
    end

    if test $installed_any -eq 0
        echo "Nothing to install."
    end

    if test $skipped_optional -gt 0
        set -l _plural dependencies
        test $skipped_optional -eq 1; and set _plural dependency
        set_color brblack
        echo "Skipped $skipped_optional optional $_plural. Run 'fish-deps install --optional' to include them."
        set_color normal
    end

    if test $skipped_terminals -gt 0
        set -l _plural "terminal emulators"
        test $skipped_terminals -eq 1; and set _plural "terminal emulator"
        set_color brblack
        echo "Skipped $skipped_terminals $_plural. Run 'fish-deps install --terminals' to include them."
        set_color normal
    end

    # Explicit terminal status: a trailing `if` with no branch taken would
    # resolve $status to 0 whatever happened above.
    if test (count $failed) -gt 0
        echo "$c_err"(count $failed)" install(s) failed: $c_cmd$failed$c_reset" >&2
        return 1
    end
    return 0
end
