# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# PRESET   safe-rm
# SUMMARY  rm that asks first when you delete recursively
#
#   fish-template new rmr --preset safe-rm
set -l __ft_use command confirm
set -l command_cmd rm
set -l confirm_prompt 'Delete recursively?'
set -l confirm_only_if '(^| )(-[a-zA-Z]*[rR]|--recursive)'
