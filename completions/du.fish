# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for the du shadow.
#
# Loads fish's own du completions (this file hides them), then adds the tool
# selectors the shadow handles itself while its C3 guard is on.

__fish_source_upstream_completion du (status filename)

set -l on '__fish_config_op_enabled du 2>/dev/null'

complete -c du -n "$on" -l disk -d 'Show mounted disk usage (duf)'
complete -c du -n "$on" -l dir -d 'Show directory tree sizes (dust)'
complete -c du -n "$on" -l dua -d 'Analyze disk usage (dua)'
