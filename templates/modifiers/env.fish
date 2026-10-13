# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  env
# KIND      modifier
# PHASE     prepare
# ORDER     30
# APPLIES   command fallback sequence dispatcher snippet per-host per-os jump
# SUMMARY   Set or remove environment variables for this command only
# PHRASE    with a modified environment

#   ─────────────────────────────── Settings ───────────────────────────────

# Variables to set, one per line as NAME=value. (lines)
set -l env_set

# Variables to remove (command, fallback and snippet targets only). (list)
set -l env_unset

#   ─────────────────────────────── Fragment ───────────────────────────────

for __ft_kv in $env_set
    set -l __ft_pair (string split -m1 = -- $__ft_kv)
    set -fx $__ft_pair[1] $__ft_pair[2]
end
if set -q env_unset[1]; and set -q cmd[1]
    set -l __ft_envargs
    for __ft_var in $env_unset
        set -a __ft_envargs -u $__ft_var
    end
    set cmd env $__ft_envargs $cmd
end
