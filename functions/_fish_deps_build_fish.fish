# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm), network
#
# SYNOPSIS
#   _fish_deps_build_fish
#
# DESCRIPTION
#   Builds and installs fish from source: clones the upstream repository
#   into a temporary directory, checks out the newest `fish-*` tag if there
#   is one, and runs `cargo install --locked --path .` (to $CARGO_HOME/bin).
#   Shared by `fish-deps install` and `fish-deps update`.
#
#   The build is wrapped in `uv run --no-project --with sphinx`. Sphinx is
#   there for one reason: fish's build script renders its man pages with
#   `sphinx-build`, and without it on PATH they are skipped. The wrapper
#   deliberately ignores upstream's pyproject.toml, which pins
#   `requires-python >= 3.13` "for reproducibility" while noting that lower
#   versions work. With `--no-project`, uv takes whatever Python 3 the system
#   has and resolves a Sphinx that supports it, and downloads a managed
#   Python itself only if there is none, so the build works on any distro
#   (Ubuntu 22.04 and 24.04 ship 3.10 and 3.12).
#
#   `--locked` makes cargo honor the repository's Cargo.lock instead of
#   re-resolving every dependency to its newest release.
#
# EXIT STATUS
#   0  fish was built and installed
#   1  The clone, checkout, or build failed
#
# EXAMPLE
#   _fish_deps_build_fish; and echo "restart your shell"
function _fish_deps_build_fish
    set -l tmpdir (mktemp -d)
    set -l ok 0

    git clone https://github.com/fish-shell/fish-shell "$tmpdir"
    and begin
        # Upstream's release tags are bare version numbers (4.9.3), so this
        # pattern matches nothing and the default branch is built as cloned.
        # Pre-existing behavior, kept as-is here and tracked separately.
        set -l tag (git -C "$tmpdir" tag --list 'fish-*' --sort=version:refname | tail -1)
        test -n "$tag"; and git -C "$tmpdir" checkout "$tag"
        true
    end
    and pushd "$tmpdir"
    and uv run --no-project --with sphinx -- cargo install --locked --path .
    and set ok 1

    popd 2>/dev/null
    rm -rf "$tmpdir"
    test $ok -eq 1
end
