# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_meta FILE KEY
#
# DESCRIPTION
#   Prints the value of a template's `# KEY  value` metadata line. KEY is
#   an upper-case word (TEMPLATE, KIND, PHASE, ORDER, APPLIES, SUMMARY,
#   PHRASE, SYNOPSIS, STATUS, EXAMPLE); setting prompts are sentence case,
#   so they never match.
#
# EXIT STATUS
#   0  Found
#   1  Absent
function __fish_template_meta --argument-names file key --description 'Read a fish-template metadata line'
    set -l v (string match -r --groups-only -- '^# '$key'\s+(\S.*)$' <$file)
    set -q v[1]; or return 1
    echo $v[1]
end
