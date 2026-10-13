# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  log
# KIND      modifier
# PHASE     prepare
# ORDER     70
# APPLIES   command fallback sequence dispatcher snippet per-host per-os jump
# SUMMARY   Save the output to a log file as well as showing it
# PHRASE    saving its output to {log_file}

#   ─────────────────────────────── Settings ───────────────────────────────

# File to save the output in. (path, required)
set -l log_file

# Add each run to the file, or replace it. (choice: append overwrite)
set -l log_mode append

#   ─────────────────────────────── Fragment ───────────────────────────────

set __ft_log $log_file
test "$log_mode" = overwrite; and set __ft_tee_flag
command mkdir -p (path dirname -- $log_file)
