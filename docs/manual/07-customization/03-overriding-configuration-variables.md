---
title: Overriding Configuration Variables
---

Any variable set in local.fish after the main config loads takes effect.
Example: to increase the scrollback history limit:

    # in local.fish
    set -gx SCROLLBACK_HISTORY_MAX_FILES 200

