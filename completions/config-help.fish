# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for config-help.
#
# The one positional is a section keyword: the keys of the manual's index
# (docs/fish-config.index), described by the heading each one opens at.

function __config_help_sections
    set -l idx $__fish_config_dir/docs/fish-config.index
    test -r $idx; or return
    string match -rv '^\s*(#|$)' <$idx \
        | string replace -r '^([^=]+)=#*\s*(.*)$' '$1\t$2'
end

function __config_help_needs_section
    set -l words (commandline -opc)
    set -e words[1]
    set -l positional (string match -v -- '-*' $words)
    not set -q positional[1]
end

complete -c config-help -f
complete -c config-help -s h -l help -d 'Show help'
complete -c config-help -s w -l html -d 'Open the documentation website'
complete -c config-help -s m -l man -d 'Open the compiled man page'
complete -c config-help -n __config_help_needs_section -a '(__config_help_sections)'
