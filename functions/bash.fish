# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# bash switches to bash shell
function bash --wraps='bash' --description 'bash switches to bash shell'
    set SHELL $(which bash) # Set shell to bash
    command bash --rcfile "$XDG_CONFIG_HOME/bash/bashrc" $argv # Run bash
    set SHELL $(which fish) # Reset shell
end
