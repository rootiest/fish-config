# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  retry
# KIND      modifier
# PHASE     prepare
# ORDER     60
# APPLIES   command fallback sequence dispatcher
# SUMMARY   Try again when the command fails
# PHRASE    trying up to {retry_attempts} times

#   ─────────────────────────────── Settings ───────────────────────────────

# How many times to try in total. (int, required)
set -l retry_attempts 3

# Seconds to wait between attempts. (int)
set -l retry_delay 2

#   ─────────────────────────────── Fragment ───────────────────────────────

set __ft_attempts $retry_attempts
set __ft_delay $retry_delay
