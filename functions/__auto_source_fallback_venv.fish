# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function __auto_source_fallback_venv --on-variable PWD
    status --is-command-substitution; and return
    
    # 1. Skip if direnv is already managing this directory
    if set -q DIRENV_DIR; or test -e ".envrc"
        return
    end
    
    # 2. If we are already in a venv, check if we've left its tree
        if set -q VIRTUAL_ENV
                # Check if the current PWD is still within the directory that owns the venv
                # (Assuming the venv is at the root of the project)
                set -l venv_root (string replace -r '/.venv$' '' $VIRTUAL_ENV)
                if not string match -q "$venv_root*" "$PWD"
                        type -q deactivate; and deactivate
                end
                return
        end
    
        # 3. Only source the venv if we aren't already in one
    if test -e ".venv/bin/activate.fish"
        source .venv/bin/activate.fish
    end
end
