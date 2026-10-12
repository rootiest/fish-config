# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

set -l subs list info new edit regen show ls help
complete -c fish-template -f
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a list -d 'List templates and presets'
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a info -d 'Show a template or preset'
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a new -d 'Create a function'
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a edit -d 'Change a generated function'
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a regen -d 'Rebuild generated functions'
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a show -d 'Print a function recipe'
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a ls -d 'List generated functions'
complete -c fish-template -n "not __fish_seen_subcommand_from $subs" -a help -d 'Show help'
complete -c fish-template -n "__fish_seen_subcommand_from info" -a "(__fish_template_names; __fish_template_names preset)"
complete -c fish-template -n "__fish_seen_subcommand_from edit regen show" -a "(__fish_template_generated (__fish_user_dots_dir)/functions)"
complete -c fish-template -n "__fish_seen_subcommand_from new edit" -s t -l target -x -a "(__fish_template_names target)" -d 'Target template'
complete -c fish-template -n "__fish_seen_subcommand_from new edit" -s w -l with -x -a "(__fish_template_names modifier)" -d 'Modifier to stack'
complete -c fish-template -n "__fish_seen_subcommand_from new edit" -s s -l set -x -a "(for t in (__fish_template_names); __fish_template_settings (__fish_template_file \$t) | string replace -r '\t.*' '='; end)" -d 'Give a setting'
complete -c fish-template -n "__fish_seen_subcommand_from new" -s p -l preset -x -a "(__fish_template_names preset)" -d 'Start from a preset'
complete -c fish-template -n "__fish_seen_subcommand_from new" -s f -l from -r -F -d 'Recipe file'
complete -c fish-template -n "__fish_seen_subcommand_from new edit regen show ls" -s o -l output -x -a "(__fish_complete_directories)" -d 'Output directory'
complete -c fish-template -n "__fish_seen_subcommand_from new" -s n -l dry-run -d 'Print instead of writing'
complete -c fish-template -n "__fish_seen_subcommand_from new edit" -s y -l yes -d 'Ask nothing'
complete -c fish-template -n "__fish_seen_subcommand_from new" -l force -d 'Replace an existing file'
complete -c fish-template -n "__fish_seen_subcommand_from regen" -l all -d 'Rebuild every generated function'
