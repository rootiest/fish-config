# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_pagetab <active_idx> <iw>
#
# DESCRIPTION
#   Renders the four-page tab strip used as the header line of every
#   config-settings page. Pages: 0 Universal, 1 Session, 2 Sponge, 3 Paths.
#   The active page is marked with a filled bullet and bold text; the others
#   with a hollow bullet. The returned string is padded to exactly <iw>
#   printable columns (the caller adds the │ │ border and center offset).
#
# ARGUMENTS
#   active_idx  0–3, the active page index
#   iw          inner width in columns to pad the strip to
#
# RETURNS
#   0  Always; prints the tab strip (no trailing newline beyond printf's)
#
# EXAMPLE
#   set strip (__config_settings_pagetab 2 76)
function __config_settings_pagetab
    set -l active $argv[1]
    set -l iw     $argv[2]

    set -l c_hi    (set_color --bold white)
    set -l c_reset (set_color normal)
    set -l names Universal Session Sponge Paths

    set -l strip ' '
    for i in (seq 0 3)
        set -l idx (math $i + 1)
        if test $i -eq $active
            set strip "$strip$c_hi●$names[$idx]$c_reset  "
        else
            set strip "$strip○$names[$idx]  "
        end
    end
    # string pad is width-aware: color escapes count as 0 columns, the bullets
    # and letters as their printable width.
    string pad -r -w $iw -- $strip
end
