# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   10-network
#
# SYNOPSIS
#   qr [text...]
#
# DESCRIPTION
#   Generates a UTF-8 QR code from the given text or from stdin if no
#   argument is provided. Uses qrencode locally if available, otherwise
#   falls back to the qrenco.de API via curl.
#
# ARGUMENTS
#   text...  Text to encode; reads from stdin if omitted
#
# EXAMPLE
#   qr "https://example.com"
#   echo "hello" | qr
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
