# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_real_command <name>
#
# DESCRIPTION
#   Resolves the real on-disk binary for <name>, skipping any of this
#   config's own generated wrapper shims. The PTY-logging wrappers we drop
#   in ~/.local/bin (paru, yay) shadow the real binary on PATH; this walks
#   every PATH match in order and returns the first one that is NOT one of
#   our wrappers, identified by the "# <name>-wrapper-version:" marker line.
#
#   This intentionally never returns one of our own wrappers, so callers
#   that embed the result in a generated wrapper cannot create a shim that
#   recurses into itself.
#
# ARGUMENTS
#   name  Command name to resolve (e.g. paru, yay)
#
# RETURNS
#   0  Real binary path printed to stdout
#   1  No non-wrapper binary found on PATH (nothing printed)
#
# EXAMPLE
#   set -l real (__fish_real_command paru)   # -> /usr/bin/paru, not the shim
function __fish_real_command --argument-names name
    for p in (command -sa $name)
        # -I: binary files (real ELF binaries) count as no-match and are
        # returned; only our text wrapper scripts carry the marker and skip.
        grep -qsIF -- "# $name-wrapper-version:" $p; and continue
        echo $p
        return 0
    end
    return 1
end
