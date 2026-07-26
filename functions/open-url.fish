# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   open-url [-s|--silent] [-v|--verbose] <url>
#   open-url --help
#
# DESCRIPTION
#   Opens a URL (or file:// URI) in the best available graphical web browser,
#   backgrounded so it never blocks the terminal. Resolves a real browser
#   binary rather than deferring to xdg-open, whose MIME dispatch can hand
#   local text/html files to non-browser apps (e.g. ebook readers).
#
#   Silent by default: prints nothing on success (errors always go to stderr);
#   --silent / -s is accepted for explicitness.
#
#   Resolution order:
#     1. $fish_help_browser  (explicit override)
#     2. $BROWSER            (validated; errors if not a command)
#     3. xdg-mime default handler for x-scheme-handler/https
#     4. First known browser binary found in a built-in list
#     5. xdg-open            (last resort)
#
# ARGUMENTS
#   url            The URL or file:// URI to open (required)
#   -s, --silent   Suppress success output (the default)
#   -v, --verbose  Print which browser is being launched
#   -h, --help     Print usage and exit
#
# RETURNS
#   0  Browser launched
#   1  No URL given, invalid $BROWSER, or no browser found
#
# EXAMPLE
#   open-url https://git.rootiest.dev/rootiest/fish-config
#   open-url -v https://fish-config-docs.pages.dev/
#
# NOTES
#   Typo abbreviation: url-open (expands to open-url on space/enter).
function open-url --description 'Open a URL in the best available web browser'
    argparse h/help s/silent v/verbose -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: open-url [-s|--silent] [-v|--verbose] <url>"
        echo "Open a URL or file:// URI in the best available web browser."
        echo
        echo "  -s, --silent   Suppress success output (the default)"
        echo "  -v, --verbose  Print which browser is being launched"
        echo "  -h, --help     Show this help"
        return 0
    end

    set -l url $argv[1]
    if test -z "$url"
        set_color red
        echo "error: open-url requires a URL argument" >&2
        set_color normal
        return 1
    end

    # Browser detection — mirrors fish's help.fish priority order but
    # resolves actual browser binaries before falling back to xdg-open.
    # xdg-open dispatches on the file's MIME type (text/html), which can
    # be associated with non-browser apps (e.g. ebook readers). Using a
    # real browser binary directly with a file:// URI avoids that lookup.
    set -l graphical_browsers \
        firefox firefox-esr chromium chromium-browser google-chrome \
        brave-browser vivaldi vivaldi-stable epiphany falkon qutebrowser \
        opera x-www-browser htmlview

    set -l browser $fish_help_browser

    if not set -q browser[1]
        if set -q BROWSER
            echo $BROWSER | read -at browser
            if not type -q $browser[1]
                set_color red
                echo "error: \$BROWSER '$browser[1]' is not a valid command" >&2
                set_color normal
                return 1
            end
        else
            # Resolve the https scheme handler from xdg-mime and use its
            # binary directly — most reliable on modern Linux desktops.
            if type -q xdg-mime
                set -l desk (xdg-mime query default x-scheme-handler/https 2>/dev/null)
                if test -n "$desk"
                    set -l candidate (string replace -r '\.desktop$' '' -- $desk)
                    if type -q $candidate
                        set browser $candidate
                    end
                end
            end

            # Fall back to trying known browser binaries in order.
            if not set -q browser[1]
                for b in $graphical_browsers
                    if type -q -f $b
                        set browser $b
                        break
                    end
                end
            end

            # Last resort: xdg-open (may hit wrong app for local files).
            if not set -q browser[1]; and type -q xdg-open
                set browser xdg-open
            end
        end
    end

    if not set -q browser[1]
        set_color red
        echo "error: could not find a web browser — set \$fish_help_browser or \$BROWSER" >&2
        set_color normal
        return 1
    end

    if set -q _flag_verbose
        set_color green
        echo "Opening $browser[1]…"
        set_color normal
    end

    # Background the browser so it doesn't block the terminal, and discard its
    # own console chatter (e.g. "Opening in existing browser session.").
    sh -c '("$@") >/dev/null 2>&1 &' -- $browser $url
    return 0
end
