# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# PRESET   update-all
# SUMMARY  Update everything in one go, with a log and a notification
#
# Steps for tools that are not installed are skipped. Edit the steps when
# the wizard asks, or later with: fish-template edit update-all
set -l __ft_use sequence log notify
set -l sequence_steps 'type -q fisher; and fisher update' 'if type -q flatpak; flatpak update -y; end' 'if type -q tldr; tldr --update; end'
set -l sequence_on_fail continue
set -l log_file ~/.local/state/fish-template/update-all.log
set -l log_mode overwrite
set -l notify_on always
