# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for the ping shadow.
#
# Loads fish's own ping completions (this file hides them), then adds the
# prettyping option the shadow handles while its C3 guard is on.

__fish_source_upstream_completion ping (status filename)

complete -c ping -n '__fish_config_op_enabled ping 2>/dev/null; and command -q prettyping' \
    -l legend -d 'Show the prettyping legend (hidden by default)'
