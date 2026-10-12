# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  args
# KIND      modifier
# PHASE     prepare
# ORDER     20
# APPLIES   command fallback
# SUMMARY   Always add arguments before and/or after yours
# PHRASE    with extra arguments

#   ─────────────────────────────── Settings ───────────────────────────────

# Arguments placed before yours. (list)
set -l args_prepend

# Arguments placed after yours. (list)
set -l args_append

#   ─────────────────────────────── Fragment ───────────────────────────────

set -a cmd $args_prepend
set -a __ft_append $args_append
