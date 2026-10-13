# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  timeout
# KIND      modifier
# PHASE     prepare
# ORDER     50
# APPLIES   command fallback snippet
# SUMMARY   Stop the command if it runs too long (external commands only)
# PHRASE    stopping it after {timeout_seconds} seconds
# STATUS    124 if the time limit is reached

#   ─────────────────────────────── Settings ───────────────────────────────

# Time limit in seconds. (int, required)
set -l timeout_seconds 60

#   ─────────────────────────────── Fragment ───────────────────────────────

if command -q timeout
    set cmd timeout $timeout_seconds $cmd
else
    echo (status current-function)": timeout is not installed; running without a time limit" >&2
end
