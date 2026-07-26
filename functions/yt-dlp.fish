# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   13-media-and-utilities
#
# SYNOPSIS
#   yt-dlp [args...] URL [URL...]
#
# DESCRIPTION
#   Wraps yt-dlp, injecting sane embedding + SponsorBlock defaults
#   (--sponsorblock-remove all, --embed-subs, --embed-metadata,
#   --embed-thumbnail). Each default is suppressed if the user already
#   passes that flag, its alias, or its negation (e.g. --no-embed-thumbnail
#   drops our --embed-thumbnail). All other arguments pass through
#   untouched. --help and friends fall through to real yt-dlp.
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases
#   (or the __fish_config_opinionated master), passes straight through to
#   the system yt-dlp with no defaults injected.
#
# ARGUMENTS
#   args...  Arguments forwarded to yt-dlp (defaults prepended)
#   --no-embed-thumbnail  Skip thumbnail embedding for this run
#
# EXAMPLE
#   yt-dlp dQw4w9WgXcQ
#   yt-dlp --no-embed-thumbnail dQw4w9WgXcQ   # drops our thumbnail default
function yt-dlp --description 'yt-dlp with embedding + SponsorBlock defaults'
    # Opinionated guard (C1): fall back to bare command yt-dlp when disabled.
    if not __fish_config_op_enabled __fish_config_op_aliases
        command yt-dlp $argv
        return $status
    end

    set -l extra

    # --embed-subs (skip if set or negated)
    if not contains -- --embed-subs $argv
        and not contains -- --no-embed-subs $argv
        set -a extra --embed-subs
    end

    # --embed-thumbnail (skip if set or negated)
    if not contains -- --embed-thumbnail $argv
        and not contains -- --no-embed-thumbnail $argv
        set -a extra --embed-thumbnail
    end

    # --embed-metadata (aliases: --add-metadata / --no-add-metadata)
    if not contains -- --embed-metadata $argv
        and not contains -- --add-metadata $argv
        and not contains -- --no-embed-metadata $argv
        and not contains -- --no-add-metadata $argv
        set -a extra --embed-metadata
    end

    # --sponsorblock-remove all
    # Skip if the user set their own remove (bare or --opt=value form), or
    # disabled SponsorBlock entirely with --no-sponsorblock.
    if not string match -q -- '--sponsorblock-remove' $argv
        and not string match -q -- '--sponsorblock-remove=*' $argv
        and not contains -- --no-sponsorblock $argv
        set -a extra --sponsorblock-remove all
    end

    # User args last so an explicit flag wins any store_true/false precedence.
    command yt-dlp $extra $argv
end
