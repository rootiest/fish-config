# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function qr -d "Generate a QR code from text or pipe"
    if set -q argv[1]
        echo $argv | qrencode -t utf8
    else
        cat | qrencode -t utf8
    end
end
