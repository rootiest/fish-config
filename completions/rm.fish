# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for the rm shadow.
#
# Loads fish's own rm completions (this file hides them), then adds the
# options the shadow handles itself while its C3 guard is on.

__fish_source_upstream_completion rm (status filename)

set -l on '__fish_config_op_enabled rm 2>/dev/null'

complete -c rm -n "$on; and test (count (commandline -opc)) -eq 1" \
    -s e -l empty -d 'Empty the trash (all of it, or the given trash options)'
complete -c rm -n "$on" -s S -l secure -d 'Delete permanently (rm -rf), then fstrim'
