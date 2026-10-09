# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_refresh_path
#
# DESCRIPTION
#   Puts the bin directories that installers write into on this session's
#   $PATH, so a tool installed a moment ago is usable by the very next step
#   without restarting the shell. It covers cargo and rustup ($CARGO_HOME/bin
#   and ~/.cargo/bin), uv and wakatime (~/.local/bin), and `go install`
#   ($GOBIN, or $GOPATH/bin).
#
#   Directories are added session-only (`fish_add_path -g`); a new shell
#   gets them from config.fish as usual. A directory that is missing or
#   already on $PATH is left alone, so the existing order is not disturbed.
#
#   Every candidate is considered, not just the first that exists: rustup
#   installs under ~/.cargo when CARGO_HOME was not exported yet, while
#   `cargo install` writes under $CARGO_HOME, and both must be reachable.
#
# EXAMPLE
#   _fish_deps_refresh_path
function _fish_deps_refresh_path
    set -l dirs
    set -q CARGO_HOME; and test -n "$CARGO_HOME"; and set -a dirs "$CARGO_HOME/bin"
    set -a dirs "$HOME/.cargo/bin" "$HOME/.local/bin"

    if command -q go
        set -l gobin (go env GOBIN 2>/dev/null)
        if test -z "$gobin"
            set gobin (go env GOPATH 2>/dev/null)/bin
        end
        test "$gobin" != /bin; and set -a dirs "$gobin"
    end

    for d in $dirs
        if test -d "$d"; and not contains -- "$d" $PATH
            fish_add_path -g "$d"
        end
    end
    return 0
end
