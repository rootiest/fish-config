# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   fish_mode_prompt
#
# DESCRIPTION
#   Empty override. Suppresses fish's built-in vi-mode prefix ([N]/[I]/etc.)
#   that would prepend to the prompt line and break the two-line nim layout.
#   Vi-mode display is handled inside fish_prompt itself.
#
# EXAMPLE
#   # Rendered automatically by fish; not called directly.

function fish_mode_prompt
end
