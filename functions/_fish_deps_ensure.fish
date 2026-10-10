# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   network, blocking-prompt
#
# SYNOPSIS
#   _fish_deps_ensure NEED
#
# DESCRIPTION
#   Makes sure a build prerequisite of the fish-deps installers is present,
#   offering to install it from the system package manager when it is not.
#   These are tools the installers assume exist but a fresh server often
#   lacks, and which are not catalog entries themselves:
#
#     cc         A C compiler/linker. Every cargo install needs cc to link
#                (build-essential, base-devel, gcc).
#     toolchain  A working Rust toolchain. A rustup shim with no default
#                toolchain answers every cargo command with "rustup could not
#                choose a version of cargo"; this offers rustup default
#                stable.
#     cargo      Both of the above, toolchain first.
#     unzip      Needed to unpack the wakatime-cli release zip.
#     go         The Go toolchain, for go install of ov (which most distros
#                do not package).
#
#   Each need is asked about once per run: the first answer (installed, or
#   declined, or failed) is remembered in $_fdc_ensure_NEED, so a dozen
#   cargo installs do not repeat the same question. The installer clears
#   those variables when it starts.
#
#   When the package manager is unknown, or has no package for the need, the
#   manual steps are printed instead.
#
# ARGUMENTS
#   NEED  One of: cc, toolchain, cargo, unzip, go
#
# EXIT STATUS
#   0    The prerequisite is present
#   1    It is missing, was declined, or could not be installed
#   2    Unknown NEED
#   130  The user quit (q, Ctrl+C or Ctrl+D) at the prompt
#
# EXAMPLE
#   _fish_deps_ensure cargo; and cargo install --locked eza
function _fish_deps_ensure --argument-names need
    set -l memo _fdc_ensure_$need
    if set -q $memo
        return $$memo
    end
    __fish_palette

    switch $need
        case cargo
            _fish_deps_ensure toolchain
            or return $status
            _fish_deps_ensure cc
            return $status
        case cc unzip go toolchain
        case '*'
            return 2
    end

    # -- Is it already there? -------------------------------------------
    switch $need
        case cc
            command -q cc; and set -g $memo 0
        case unzip
            command -q unzip; and set -g $memo 0
        case go
            command -q go; and set -g $memo 0
        case toolchain
            # No cargo at all is not this check's business: the caller only
            # asks once cargo is on PATH, and a missing cargo is reported there.
            if not command -q cargo; or cargo --version >/dev/null 2>&1
                set -g $memo 0
            end
    end
    set -q $memo; and return 0

    # -- Rust toolchain: rustup is the fix, not the package manager ---------
    if test "$need" = toolchain
        if not command -q rustup
            set -g $memo 1
            return 1
        end
        echo "  $c_warn""cargo is installed but rustup has no default toolchain configured.$c_reset"
        _fish_deps_ask "  Run 'rustup default stable' to install one?"
        switch $status
            case 1
                set -g $memo 1
                return 1
            case 2
                return 130
        end
        rustup default stable
        _fish_deps_refresh_path
        if cargo --version >/dev/null 2>&1
            set -g $memo 0
        else
            set -g $memo 1
        end
        return $$memo
    end

    # -- Everything else comes from the system package manager ------------
    set -l why
    set -l manual
    switch $need
        case cc
            set why "a C compiler/linker (cc) — Rust tools cannot be built without one"
            set manual "install your distro's build tools (build-essential, base-devel or gcc) and re-run fish-deps install"
        case unzip
            set why "unzip — needed to unpack the wakatime-cli release"
            set manual "install the unzip package with your package manager and re-run fish-deps install"
        case go
            set why "Go — needed to install the latest ov, which most distros do not package"
            set manual "install Go from https://go.dev/doc/install (or your distro's golang package) and re-run fish-deps install"
    end

    set -l pm (_fish_deps_detect_pm)
    set -l pkg
    test -n "$pm"; and set pkg (_fish_deps_pm_pkg $pm $need)
    if test -z "$pkg"
        echo "  $c_warn""Missing $why.$c_reset"
        echo "  No package for it is known for this system — $manual."
        set -g $memo 1
        return 1
    end

    echo "  $c_warn""Missing $why.$c_reset"
    _fish_deps_ask "  Install $pkg via $pm?"
    switch $status
        case 1
            set -g $memo 1
            return 1
        case 2
            return 130
    end

    _fish_deps_pm_install $pkg
    set -l rc $status
    _fish_deps_refresh_path

    if test $rc -eq 130
        return 130
    end
    # NEED is also the binary name for every case that reaches this point.
    if test $rc -eq 0; and command -q $need
        set -g $memo 0
    else
        echo "  $c_err""Could not install $pkg — $manual.$c_reset" >&2
        set -g $memo 1
    end
    return $$memo
end
