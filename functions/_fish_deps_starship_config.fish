# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   blocking-prompt
#
# SYNOPSIS
#   _fish_deps_starship_config [--quiet] [--force]
#
# DESCRIPTION
#   The second stage of the fish-deps starship install: puts the prompt
#   config this repository ships (data/starship.toml) where starship reads
#   it, $STARSHIP_CONFIG when that is set, else ~/.config/starship.toml.
#
#   Without --force an existing config, or anything else already at that
#   path, is never modified. The run says it was left alone and where the
#   shipped default lives, so the two can be compared; --quiet leaves that
#   note out, for runs where starship was already installed and nothing was
#   asked about it.
#
#   With --force (fish-deps install starship-config) an existing config is
#   replaced: it is first renamed to a backup next to it,
#   <name>.bak-YYYYMMDD-HHMMSS, then the default is written. A config that
#   is already identical to the default is left as it is, with no backup.
#   A symlink is renamed as it is, so the file it points to is untouched.
#
#   Every write is asked about first, through _fish_deps_ask, so --yes
#   accepts and q stops the whole run.
#
#   The same file serves every distro: starship's os module picks the icon
#   at runtime from [os.symbols], which maps Arch, CachyOS (to the Arch
#   icon), Debian, Ubuntu and the rest.
#
#   $__fish_deps_starship_default, when set, replaces the shipped file's
#   path (for tests).
#
# ARGUMENTS
#   --quiet  Say nothing when a config already exists (ignored with --force)
#   --force  Back up and replace an existing config
#
# EXIT STATUS
#   0    The default config was written
#   1    It could not be written (the shipped file is missing, the target is
#        a directory, or the backup or the copy failed)
#   2    Nothing to do: a config already exists (without --force), it is
#        already the default, or the offer was declined
#   130  q, Ctrl+C or Ctrl+D at the prompt
#
# EXAMPLE
#   _fish_deps_starship_config
#   _fish_deps_starship_config --quiet
#   _fish_deps_starship_config --force
function _fish_deps_starship_config
    __fish_palette
    set -l quiet 0
    set -l force 0
    contains -- --quiet $argv; and set quiet 1
    contains -- --force $argv; and set force 1

    set -l default $__fish_config_dir/data/starship.toml
    set -q __fish_deps_starship_default; and set default $__fish_deps_starship_default

    set -l target $HOME/.config/starship.toml
    test -n "$STARSHIP_CONFIG"; and set target $STARSHIP_CONFIG

    # test -L too: a dangling symlink is still someone's config, and cp
    # would refuse to write through it anyway.
    set -l exists 0
    if test -e $target; or test -L $target
        set exists 1
    end

    if test $exists -eq 1; and test $force -eq 0
        if test $quiet -eq 0
            echo -n (__fish_color brblack)
            echo "  starship config already exists ($target), left unchanged."
            echo "  The default is $default, to compare."
            echo "  fish-deps install starship-config replaces it, keeping a backup."
            echo -n (__fish_color normal)
        end
        return 2
    end

    if not test -f $default
        echo "$c_err  The default starship config is missing ($default).$c_reset" >&2
        return 1
    end

    set -l backup
    if test $exists -eq 1
        if test -d $target
            echo "$c_err  $target is a directory, not a starship config.$c_reset" >&2
            return 1
        end
        if not test -L $target; and test -f $target
            and test "$(string collect <$target)" = "$(string collect <$default)"
            echo -n (__fish_color brblack)
            echo "  starship config is already the default ($target)."
            echo -n (__fish_color normal)
            return 2
        end
        set backup $target.bak-(command date +%Y%m%d-%H%M%S)
        set -l n 1
        while test -e $backup; or test -L $backup
            set backup $target.bak-(command date +%Y%m%d-%H%M%S)-$n
            set n (math $n + 1)
        end
        _fish_deps_ask "Replace the starship config ($target)? The current one is kept as $backup."
    else
        _fish_deps_ask "Install the default starship config ($target)?"
    end
    switch $status
        case 1
            return 2
        case 2
            return 130
    end

    # command: cp, mv and mkdir may be interactive shadows. mv -n: the
    # backup name was free a moment ago, and must not clobber anything now.
    if set -q backup[1]
        if not command mv -n -- $target $backup; or test -e $target; or test -L $target
            echo "$c_err  Could not back up $target; nothing was replaced.$c_reset" >&2
            return 1
        end
        echo -n (__fish_color brblack)
        echo "  The previous starship config is now $backup."
        echo -n (__fish_color normal)
    end
    if command mkdir -p (path dirname -- $target); and command cp -- $default $target
        echo -n (__fish_color green)
        echo "  starship config installed ($target)."
        echo -n (__fish_color normal)
        return 0
    end
    echo "$c_err  starship config install failed ($target).$c_reset" >&2
    return 1
end
