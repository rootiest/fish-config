# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for open-url.
#
# The positional is a URL or file:// URI, which nothing local can complete, so
# file completion is off.

complete -c open-url -f
complete -c open-url -s h -l help -d 'Show help message'
complete -c open-url -s s -l silent -d 'Suppress success output (the default)'
complete -c open-url -s v -l verbose -d 'Print which browser is being launched'
