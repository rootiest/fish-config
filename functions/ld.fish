# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function ld --description 'Run lazydocker on the current Docker context'
    # Fetch the host endpoint of the currently active Docker context
    set -l current_host (docker context inspect --format '{{.Endpoints.docker.Host}}')

    # Run lazydocker with the DOCKER_HOST variable set for this command only
    env DOCKER_HOST=$current_host lazydocker
end
