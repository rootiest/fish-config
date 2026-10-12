# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# PRESET   allow-telemetry
# SUMMARY  Run one command without DO_NOT_TRACK and DISABLE_TELEMETRY
#
# Some tools turn features off when a global telemetry opt-out is set
# (claude-code disables Remote Control). This keeps the opt-out for every
# other command. Name the function after the command it wraps:
#   fish-template new claude --preset allow-telemetry
set -l __ft_use command env
set -l command_cmd claude
set -l env_unset DO_NOT_TRACK DISABLE_TELEMETRY
