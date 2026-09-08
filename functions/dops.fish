# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# DEPENDENCIES
#   docker
#
# SYNOPSIS
#   dops [args...]
#
# DESCRIPTION
#   Enhanced container listing: runs docker ps with a clean custom table
#   (Names, Image, Status, Ports) instead of docker's noisier default
#   columns. Extra arguments (e.g. -a) are forwarded to docker ps.
#
# ARGUMENTS
#   args...  Arguments forwarded to docker ps
#
# EXIT STATUS
#   Exit status of docker ps
#
# EXAMPLE
#   dops
#   dops -a
function dops --description 'Enhanced, formatted docker ps listing'
    __fish_help_header (status current-function) $argv; and return 0

    command docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' $argv
end
