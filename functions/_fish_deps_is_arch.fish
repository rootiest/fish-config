# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_is_arch
#
# DESCRIPTION
#   Reports whether this is an Arch-based system: Arch itself or a derivative
#   (CachyOS, Manjaro, EndeavourOS, Garuda, ...). It is the gate for anything
#   that only exists there, namely the AUR helpers paru and yay.
#
#   The check reads ID and ID_LIKE from os-release, falling back to
#   /etc/arch-release. The presence of a `pacman` binary is deliberately not
#   used: Debian and Ubuntu ship an unrelated game by that name.
#
#   $__fish_deps_os_release overrides the os-release path (used by the test
#   suite and by containers that mount one elsewhere).
#
# EXIT STATUS
#   0  Arch or an Arch derivative
#   1  Anything else
#
# EXAMPLE
#   _fish_deps_is_arch; and echo "AUR helpers apply here"
function _fish_deps_is_arch
    set -l release /etc/os-release
    set -q __fish_deps_os_release; and set release $__fish_deps_os_release

    if test -r "$release"
        string match -qr '^ID(_LIKE)?=["\']?([^"\'=]* )?arch(linux)?( [^"\'=]*)?["\']?$' <"$release"
        and return 0
    end
    test "$release" = /etc/os-release; and test -e /etc/arch-release
end
