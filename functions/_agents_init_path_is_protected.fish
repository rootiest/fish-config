# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_init_path_is_protected <root> <path>
#
# DESCRIPTION
#   Decides whether a real (non-symlink) file should be left alone rather
#   than adopted into the AGENTS/ mirror or replaced with a symlink,
#   because it looks like a deliberately tracked project file rather than
#   an incidental one this project hasn't yet engaged agents-init's
#   convention for.
#
#   A file is protected only when BOTH are true:
#     - it is tracked in git's index at <root> -- staged or committed, via
#       `git ls-files`. A file that has never been `git add`ed (even if it
#       sits right next to tracked files) is not tracked by this
#       definition, and neither is one that is merely gitignored.
#     - <root>/.gitignore exists and is non-empty -- a project with no
#       ignore rules at all has never engaged with the convention this
#       tool manages, so a tracked file there is more likely incidental
#       (e.g. the very first agents-init run, before anyone thought to
#       ignore it) than a deliberate choice to keep tracking it.
#
#   Neither check alone is enough: an untracked file is always safe
#   regardless of .gitignore state (nothing has been committed to protect),
#   and a tracked file in a project with no established ignore
#   conventions is treated as adoptable rather than deliberate.
#
# ARGUMENTS
#   root  Absolute path to the project root (may or may not be a git repo)
#   path  Absolute path to the file being considered
#
# EXIT STATUS
#   0  Protected -- leave this file alone
#   1  Not protected -- safe to adopt/replace
#
# EXAMPLE
#   _agents_init_path_is_protected /path/to/project /path/to/project/functions/CLAUDE.md
function _agents_init_path_is_protected --argument-names root path
    test -n "$root" -a -n "$path"; or return 1
    git -C "$root" --literal-pathspecs ls-files --error-unmatch -- "$path" >/dev/null 2>&1; or return 1
    test -s "$root/.gitignore"; or return 1
    return 0
end
