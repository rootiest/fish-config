# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │              Minimum Fish Version Warning                │
#          ╰──────────────────────────────────────────────────────────╯
#
# Warns once per interactive session, on stderr, when the running Fish is
# older than this configuration supports (see __fish_config_version_check
# for the minimum and the parsing). It is a warning only: fish sources every
# conf.d file regardless, so nothing here can stop the rest of the config
# from loading.
#
# The "00-" prefix makes this sort first among conf.d files, so the warning
# appears before any older-Fish error from a later file.
#
# Core behaviour, deliberately NOT gated by an opinionated-component guard
# (__fish_config_op_enabled): the guards switch optional features, and this
# is the notice that explains why the config misbehaves on an old Fish. It
# also has no # COMPONENT header, and the registry that the guard reads is
# not loaded yet at this point.
#
# On a supported Fish this costs one status check, one variable test and one
# function call (a plain string match, no external commands).

status is-interactive; or return
set -q __fish_config_version_warned; and return
set -g __fish_config_version_warned 1

__fish_config_version_check $version
