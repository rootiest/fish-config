# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# DEPENDENCIES
#   jobrunner
#
# SYNOPSIS
#   jr [<subcommand>] [<name>] [<command>...]
#
# DESCRIPTION
#   Shorthand for jobrunner. Accepts the same subcommands, flags, and
#   shorthands, and inherits its completions.
#
# ARGUMENTS
#   See jobrunner --help for the full argument reference.
#
# EXIT STATUS
#   Same as jobrunner.
#
# EXAMPLE
#   jr run build make -j8
#   jr list
function jr --wraps jobrunner --description 'Shorthand for jobrunner'
    jobrunner $argv
end
