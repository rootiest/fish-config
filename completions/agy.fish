# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for the agy wrapper.
#
# Loads agy's own completions if it ships any (this file would hide them),
# then adds the resume option the wrapper translates itself.

__fish_source_upstream_completion agy (status filename)

complete -c agy -s r -l resume -d 'Resume a session by id, or the most recent'
