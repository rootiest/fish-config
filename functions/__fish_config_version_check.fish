# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_version_check [VERSION]
#
# DESCRIPTION
#   Checks a Fish version string against the minimum this configuration
#   supports (4.0.0, set in the one "minimum" line in the function body).
#   When VERSION is older, or cannot be read as a version at all, prints a
#   single message to stderr and fails; when it is the minimum or newer,
#   prints nothing.
#
#   The message gives the version found, says that Fish 4.x or newer is
#   required, and points at fish-deps and the Fish Version Requirement
#   section of the troubleshooting chapter.
#
#   Parsing is plain fish string handling with no external commands, so
#   the check is cheap enough to run at every shell start. It reads the
#   leading MAJOR[.MINOR[.PATCH]] numbers and ignores anything after
#   them, so 4.0b1 and 4.1.0-12-gabc1234 (git-describe builds) are read
#   as 4.0 and 4.1.0. A missing minor or patch counts as 0.
#
#   Called at shell start by conf.d/00-version-check.fish, which passes
#   $version. This is a warning only: fish sources every conf.d file
#   regardless, so nothing here can stop the rest of the configuration
#   from loading.
#
# ARGUMENTS
#   VERSION  The version string to check, normally $version. Empty or
#            unparseable input is treated as too old.
#
# EXIT STATUS
#   0  VERSION is the minimum or newer (nothing printed)
#   1  VERSION is older than the minimum or unparseable (message on stderr)
#
# EXAMPLE
#   __fish_config_version_check $version
#   __fish_config_version_check 3.7.1; echo $status
function __fish_config_version_check --argument-names ver
    # The one place the minimum supported Fish version is defined.
    set -l minimum 4 0 0

    # Leading numbers only. Optional groups that did not take part in the
    # match may come back empty or be absent, so each is read through a
    # quoted index below, which yields an empty string either way.
    set -l m (string match -r -- '^v?(\d{1,9})(?:\.(\d{1,9}))?(?:\.(\d{1,9}))?' "$ver")
    set -l have "$m[2]" "$m[3]" "$m[4]"

    set -l older true
    if test (count $m) -gt 1
        set older false
        for i in 1 2 3
            set -l h "$have[$i]"
            test -n "$h"; or set h 0
            if test $h -gt $minimum[$i]
                break
            else if test $h -lt $minimum[$i]
                set older true
                break
            end
        end
    end

    test $older = false; and return 0

    __fish_palette
    set -l need (string join . $minimum)
    set -l found "'$ver'"
    test -n "$ver"; or set found "an unknown version"
    echo "$c_warn""fish-config:$c_reset Fish $need or newer is required, but this is $found." >&2
    echo "  Some features will fail with confusing errors. Run $c_cmd""fish-deps$c_reset for the upgrade status, or see 'Fish Version Requirement' in the troubleshooting chapter of the manual." >&2
    return 1
end
