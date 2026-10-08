# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   self-limiting(rm), bypasses-shadow(bash), network
#
# SYNOPSIS
#   _fish_deps_run_script URL SHELL [ARGS...]
#
# DESCRIPTION
#   Runs an upstream installer script without streaming it into a shell.
#   The script is downloaded to a temporary file first, and only executed
#   once curl has reported success and the file is non-empty, so a dropped
#   connection can never run a truncated script. ARGS are passed to the
#   script.
#
# ARGUMENTS
#   URL    HTTPS URL of the installer script
#   SHELL  Interpreter to run it with (sh or bash)
#   ARGS   Arguments passed through to the script
#
# EXIT STATUS
#   The script's own exit status, or:
#   1  The download failed or produced an empty file
#   2  Usage error
#
# EXAMPLE
#   _fish_deps_run_script https://starship.rs/install.sh sh --yes
function _fish_deps_run_script --argument-names url shell
    if test (count $argv) -lt 2
        echo "  usage: _fish_deps_run_script URL SHELL [ARGS...]" >&2
        return 2
    end

    set -l tmp (mktemp)
    if not curl -fsSL --proto '=https' -o "$tmp" "$url"; or not test -s "$tmp"
        echo "  Download failed: $url (installer not run)" >&2
        rm -f "$tmp"
        return 1
    end

    command $shell "$tmp" $argv[3..]
    set -l rc $status
    rm -f "$tmp"
    return $rc
end
