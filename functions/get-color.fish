# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function get-color --wraps='/home/rootiest/scripts/hex2rgb.sh "$(wl-colorpicker-plasma)"' --description 'alias get-color=/home/rootiest/scripts/hex2rgb.sh "$(wl-colorpicker-plasma)"'
  /home/rootiest/scripts/hex2rgb.sh "$(wl-colorpicker-plasma)" $argv
        
end
