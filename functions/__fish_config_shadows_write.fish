# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   __fish_config_op_enabled, __fish_config_op_registry_lookup
#
# SYNOPSIS
#   __fish_config_shadows_write [--if-stale] [--background] [--output <path>]
#
# DESCRIPTION
#   Writes docs/command-shadows.json from data/command-shadows.tsv: every
#   command this config shadows, its replacement, the toggle that controls
#   it, whether that toggle is on right now, and whether the shadow can
#   break a pasted or piped command. Agents read it to know which commands
#   to call through their bypass (command ssh) instead of the bare name.
#
#   A fingerprint of the universal opinionated toggles and the catalog's,
#   registry's and this file's mtimes is saved next to the JSON as
#   <output>.fp. conf.d/command-shadows.fish calls this with --if-stale
#   --background before every prompt, so a toggle change from any shell or
#   from config-settings reaches the file without a restart.
#
# ARGUMENTS
#   --if-stale        Do nothing when the JSON exists and the fingerprint
#                     matches the saved one
#   --background      Write from a detached child fish, which sees the
#                     universal toggles only, never this shell's session
#                     (-g) overrides
#   --output <path>   Write here instead of docs/command-shadows.json
#
# EXIT STATUS
#   0  Written, already current, or handed to the background child
#   1  The catalog is missing or the file could not be written
#   2  Usage error
#
# EXAMPLE
#   __fish_config_shadows_write
#   jq -r '.shadows[] | select(.enabled and .breaks_scripts) | .bypass' \
#       ~/.config/fish/docs/command-shadows.json
function __fish_config_shadows_write --description 'Regenerate docs/command-shadows.json from the shadow catalog'
    argparse if-stale background 'output=' -- $argv
    or return 2

    set -l catalog $__fish_config_dir/data/command-shadows.tsv
    set -l out $__fish_config_dir/docs/command-shadows.json
    set -q _flag_output; and set out $_flag_output
    set -l stamp $out.fp

    set -l fp
    for v in (set --names --universal | string match -r '^__fish_config_op.*')
        set -a fp "$v=$$v"
    end
    set -a fp (path mtime -- $catalog $__fish_config_dir/conf.d/__fish_config_op_registry.fish (status current-filename))
    set fp (string join \x1e -- $fp)

    if set -q _flag_if_stale; and test -f $out; and test -r $stamp
        read -z -l saved <$stamp
        test "$saved" = "$fp"; and return 0
    end

    if set -q _flag_background
        # The child computes and saves its own fingerprint, so a session
        # override in this shell can't end up in the file.
        set -l fish_bin (status fish-path)
        $fish_bin -c '__fish_config_shadows_write --output $argv[1]' $out &>/dev/null &
        disown
        return 0
    end

    test -r $catalog; or return 1

    set -l source (git -C $__fish_config_dir rev-parse --short HEAD 2>/dev/null)
    or set source unknown
    set -l lines '{' \
        '  "generated": "'(date -u +%Y-%m-%dT%H:%M:%SZ)'",' \
        '  "source": "fish-config '$source'",' \
        '  "usage": "An enabled shadow with breaks_scripts true can break a pasted or piped command: call its bypass instead of the bare name. when lists conditions the shadow needs beyond its toggle; null means always.",' \
        '  "shadows": ['

    set -l objects
    for line in (string match -v -r '^\s*(#|$)' <$catalog)
        # name identity site bypass when breaks replacement why
        set -l f (string split \t -- $line | string replace -a -- '\\' '\\\\' | string replace -a -- '"' '\\"')
        set -l site $f[3]
        test "$site" = -; and set site ''

        set -l toggles
        set -l categories
        set -l enabled true
        if test "$f[2]" != -
            for tag in (__fish_config_op_registry_lookup $f[2] $site)
                set -l parts (string split -m 1 -- / $tag)
                set -a toggles '"__fish_config_op_'$parts[1]_(string replace -a -- - _ $parts[2])'"'
                set -a categories '"'$parts[2]'"'
            end
            __fish_config_op_enabled $f[2] $site; or set enabled false
        end
        # One tag is the common case; more would all have to be on.
        switch (count $toggles)
            case 0
                set toggles null
                set categories null
            case 1
            case '*'
                set toggles '['(string join ', ' -- $toggles)']'
                set categories '['(string join ', ' -- $categories)']'
        end

        set -l when null
        test "$f[5]" != -; and set when '"'$f[5]'"'
        set -l why null
        test "$f[8]" != -; and set why '"'$f[8]'"'
        set -l breaks false
        test "$f[6]" = 1; and set breaks true

        set -a objects '    {
      "name": "'$f[1]'",
      "replacement": "'$f[7]'",
      "bypass": "'$f[4]'",
      "when": '$when',
      "category": '$categories',
      "toggle": '$toggles',
      "enabled": '$enabled',
      "breaks_scripts": '$breaks',
      "why": '$why'
    }'
    end
    for i in (seq (math (count $objects) - 1))
        set objects[$i] "$objects[$i],"
    end
    set -a lines $objects '  ]' '}'

    path is -d -- (path dirname -- $out); or command mkdir -p -- (path dirname -- $out); or return 1
    set -l tmp $out.tmp.$fish_pid
    printf '%s\n' $lines >$tmp
    and command mv -f -- $tmp $out
    or begin
        command rm -f -- $tmp
        return 1
    end
    printf '%s' $fp >$stamp
end
