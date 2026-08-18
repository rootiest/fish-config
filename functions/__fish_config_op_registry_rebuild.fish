# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_op_registry_rebuild
#
# DESCRIPTION
#   Regenerates conf.d/__fish_config_op_registry.fish from every
#   # COMPONENT header in functions/*.fish, conf.d/*.fish, and
#   config.fish, then re-sources it into the current session so the
#   change takes effect immediately. Run manually after editing a
#   # COMPONENT header; never run automatically at shell startup --
#   parsing every header on every new shell would be wasted work on
#   every session that isn't actively editing a header.
#
# EXIT STATUS
#   0  Registry regenerated
#   1  python3 is not available, or generation failed
#
# EXAMPLE
#   __fish_config_op_registry_rebuild
function __fish_config_op_registry_rebuild --description 'Regenerate the opinionated-component registry from # COMPONENT headers'
    if not type -q python3
        echo "__fish_config_op_registry_rebuild: python3 not found" >&2
        return 1
    end
    python3 "$__fish_config_dir/docs/generate_component_registry.py"
    or return 1
    source "$__fish_config_dir/conf.d/__fish_config_op_registry.fish"
end
