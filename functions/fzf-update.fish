# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   fzf-update
#
# DESCRIPTION
#   Installs or upgrades fzf from git HEAD into ~/.fzf. Pulls the latest
#   changes if ~/.fzf already exists, or clones the repository if not.
#
# EXAMPLE
#   fzf-update
function fzf-update --description 'Install or upgrade fzf from git HEAD'
    if test -d ~/.fzf
        echo "Updating fzf..."
        git -C ~/.fzf pull --ff-only
    else
        echo "Installing fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    end
    and ~/.fzf/install --bin
    and echo "fzf $(fzf --version) ready. Restart your shell to activate."
end
