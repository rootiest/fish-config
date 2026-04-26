# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function sbver --wraps='~/sbctl-verify-clean.sh' --description 'alias sbver=~/sbctl-verify-clean.sh'
  ~/sbctl-verify-clean.sh $argv
        
end
