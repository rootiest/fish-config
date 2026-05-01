# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Generate a QR code from text or pipe
function qr --description 'Generate a QR code from text or pipe'
    if type -q qrencode
        if set -q argv[1]
            echo $argv | qrencode -t utf8
        else
            cat | qrencode -t utf8
        end
    else
        if set -q argv[1]
            curl -s "qrenco.de/$argv"
        else
            set -l input (cat)
            curl -s "qrenco.de/$input"
        end
    end
end
