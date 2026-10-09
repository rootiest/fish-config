# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# DEPENDENCIES
#   __fish_palette, curl, jq, bd, git
#
# SYNOPSIS
#   bd-pull [--push] [-h | --help] <owner/repo>
#
# DESCRIPTION
#   Fetches unlinked issues from a Gitea repository, creates corresponding local
#   Beads entries, and updates the Gitea issue titles to include the new Bead IDs.
#   Requires $GITEA_TOKEN and $GITEA_URL to be set.
#
#   Only open issues are considered: the query asks for type=issues and
#   state=open, and pull requests or closed entries that still slip through
#   are dropped. The issues endpoint is paginated (50 per page); pages are
#   followed until one comes back empty or shorter than the first, up to a
#   fixed upper bound of 200 pages.
#
#   Every HTTP request uses curl -f, so an error status (a bad token, a wrong
#   URL, a missing repository) is reported on stderr and the response body is
#   never handed to jq. Nothing is created locally or on Gitea when listing
#   the issues fails. The API token is never placed on a command line: it is
#   written to a mode 600 curl config file in a private temporary directory
#   that is removed on exit. The title update payload is built with jq
#   --arg, so quotes and backslashes in a title cannot break or alter it.
#
#   An issue whose Bead ID cannot be determined is skipped with a warning on
#   stderr; its Gitea title is left untouched.
#
#   After linking, the Beads store is synced and ONLY .beads/issues.jsonl is
#   committed (anything else already staged is left alone). The commit is
#   not pushed unless --push is given.
#
# ARGUMENTS
#   owner/repo  The repository path in owner/name format
#   --push      Push the commit after creating it (default: do not push)
#   -h, --help  Show this help
#
# EXIT STATUS
#   0  Issues linked and synced (or no unlinked issues found)
#   1  GITEA_TOKEN or GITEA_URL not set, a required tool (curl, jq, bd, git)
#      is missing, the Gitea API request failed, or an issue could not be
#      linked, committed or pushed
#   2  Missing or malformed repository argument, or an unknown option
#
# EXAMPLE
#   bd-pull myuser/myproject
#   bd-pull --push rootiest/fish-config
function bd-pull --description 'Pull new Gitea issues into local Beads and link them'
    __fish_help_header (status current-function) $argv; and return 0
    __fish_palette

    argparse -n bd-pull h/help push -- $argv
    or return
    if set -q _flag_help
        __fish_help_header (status current-function) --help
        return 0
    end

    if not set -q argv[1]
        echo "$c_err""bd-pull: need a repository as owner/name$c_reset" >&2
        return 2
    end
    set -l REPO $argv[1]
    if not string match -qr '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -- $REPO
        echo "$c_err""bd-pull: '$REPO' is not in owner/name format$c_reset" >&2
        return 2
    end
    if test -z "$GITEA_TOKEN"
        echo "$c_err""bd-pull: \$GITEA_TOKEN not set$c_reset" >&2
        return 1
    end
    if test -z "$GITEA_URL"
        echo "$c_err""bd-pull: \$GITEA_URL not set$c_reset" >&2
        return 1
    end
    for tool in curl jq bd git
        if not type -q $tool
            echo "$c_err""bd-pull: required tool '$tool' not found in PATH$c_reset" >&2
            return 1
        end
    end

    set -l base (string replace -r '/+$' '' -- $GITEA_URL)
    set -l limit 50
    set -l max_pages 200

    # Private scratch space (mktemp -d is mode 700). It holds the curl config
    # carrying the token, so it is removed on every path out of this function:
    # everything below runs in a one-pass loop and leaves with `break`.
    set -l tmp (command mktemp -d)
    or begin
        echo "$c_err""bd-pull: could not create a temporary directory$c_reset" >&2
        return 1
    end
    set -l cfg $tmp/curl.cfg
    set -l page_file $tmp/page.json
    set -l err_file $tmp/curl.err
    set -l payload $tmp/payload.json
    set -l all $tmp/issues.jsonl

    set -l rc 0
    for _once in 1
        # Token goes through a curl config file, never argv. Backslashes and
        # quotes are escaped for curl's config syntax.
        set -l esc (string replace -a '\\' '\\\\' -- $GITEA_TOKEN | string replace -a '"' '\\"')
        command touch $cfg $all
        and command chmod 600 $cfg
        and printf 'header = "Authorization: token %s"\n' $esc >$cfg
        if test $status -ne 0
            echo "$c_err""bd-pull: could not write the temporary curl config$c_reset" >&2
            set rc 1
            break
        end

        echo (set_color blue)"📡 Checking Gitea: $REPO..."(set_color normal)

        # 1. Fetch every page of open issues (pull requests excluded).
        set -l page 1
        set -l first_n -1
        while true
            set -l url "$base/api/v1/repos/$REPO/issues?type=issues&state=open&limit=$limit&page=$page"
            curl -fsS --max-time 30 -K $cfg $url >$page_file 2>$err_file
            set -l cs $status
            if test $cs -ne 0
                set -l why (string collect <$err_file)
                test -n "$why"; or set why "curl exit status $cs"
                echo "$c_err""bd-pull: Gitea request failed: $why$c_reset" >&2
                if string match -qr '\b(401|403)\b' -- $why
                    echo "$c_err""bd-pull: check that \$GITEA_TOKEN is valid and may read $REPO$c_reset" >&2
                else if string match -qr '\b404\b' -- $why
                    echo "$c_err""bd-pull: check \$GITEA_URL ($base) and the repository name$c_reset" >&2
                else if contains -- $cs 6 7 28 35 60
                    echo "$c_err""bd-pull: could not reach \$GITEA_URL ($base)$c_reset" >&2
                end
                set rc 1
                break
            end
            if not jq -e 'type == "array"' <$page_file >/dev/null 2>&1
                echo "$c_err""bd-pull: unexpected (non-list) response from $base$c_reset" >&2
                set rc 1
                break
            end
            set -l n (jq 'length' <$page_file)
            if test $first_n -lt 0
                set first_n $n
            end
            jq -c '.[] | select(.pull_request == null and ((.state // "open") == "open"))' <$page_file >>$all
            if test $status -ne 0
                echo "$c_err""bd-pull: could not parse the issue list from $base$c_reset" >&2
                set rc 1
                break
            end
            if test $n -eq 0; or test $n -lt $first_n
                break
            end
            set page (math $page + 1)
            if test $page -gt $max_pages
                echo "$c_warn""bd-pull: stopped after $max_pages pages; later issues were not fetched$c_reset" >&2
                break
            end
        end
        test $rc -eq 0; or break

        # 2. Iterate through the issues that are not yet linked.
        set -l issues (command cat $all)
        set -l unlinked 0
        set -l created 0
        set -l linked 0
        for line in $issues
            set -l number (printf '%s\n' $line | jq -r '.number')
            set -l title (printf '%s\n' $line | jq -r '.title // ""' | string collect)

            # If it already has [ID] brackets it is linked; only "Web-Original"
            # issues are processed.
            string match -qr '^\[.*\]' -- $title; and continue

            set unlinked (math $unlinked + 1)
            echo (set_color yellow)"➕ Linking Web Issue #$number: $title"(set_color normal)

            # A. Create local Bead and capture the new ID
            # This captures the output of bd create to find the ID it generated
            set -l bd_output (bd create --title "$title")
            set -l bd_status $status
            if test $bd_status -ne 0
                echo "$c_warn""bd-pull: bd create failed for #$number; skipping$c_reset" >&2
                set rc 1
                continue
            end
            set -l found (string match -r 'bd-[a-z0-9]+' -- $bd_output)
            set -l bid $found[1]

            if test -z "$bid"
                # Fallback: find the latest ID in the jsonl if regex fails
                set -l last (tail -n 1 .beads/issues.jsonl 2>/dev/null | jq -r '.id // empty' 2>/dev/null)
                set bid $last[1]
            end

            # Never rewrite a Gitea title around an unknown ID ("[ ] title").
            if test -z "$bid"; or test "$bid" = null
                echo "$c_warn""bd-pull: could not determine the Bead ID for #$number; Gitea title left unchanged (a Bead was created locally and will not be linked on the next run)$c_reset" >&2
                set rc 1
                continue
            end
            set created (math $created + 1)

            # B. Update the Gitea Issue Title IMMEDIATELY via API
            # This prevents the Gitea Action from creating a duplicate.
            # The payload is built by jq so quotes/backslashes stay valid JSON.
            jq -nc --arg t "[$bid] $title" '{title: $t}' >$payload
            curl -fsS --max-time 30 -K $cfg -X PATCH \
                -H "Content-Type: application/json" \
                --data-binary @$payload \
                "$base/api/v1/repos/$REPO/issues/$number" >/dev/null 2>$err_file
            set -l ps $status
            if test $ps -ne 0
                set -l why (string collect <$err_file)
                test -n "$why"; or set why "curl exit status $ps"
                echo "$c_warn""bd-pull: could not update the title of #$number ($bid): $why$c_reset" >&2
                set rc 1
                continue
            end

            set linked (math $linked + 1)
        end

        if test $unlinked -eq 0
            echo "⠿ No unlinked issues found."
            break
        end

        if test $created -eq 0
            break
        end

        echo (set_color green)"✅ Linked $linked issues."(set_color normal)
        if not bd sync
            echo "$c_warn""bd-pull: bd sync failed$c_reset" >&2
            set rc 1
        end

        # Commit ONLY the Beads file: `git commit -- <path>` leaves anything
        # else the user has already staged out of this commit.
        if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
            echo "$c_warn""bd-pull: not inside a git work tree; nothing committed$c_reset" >&2
            set rc 1
            break
        end
        if not git add -- .beads/issues.jsonl
            echo "$c_warn""bd-pull: could not stage .beads/issues.jsonl$c_reset" >&2
            set rc 1
            break
        end
        if git diff --cached --quiet -- .beads/issues.jsonl
            echo "⠿ .beads/issues.jsonl is unchanged; nothing to commit."
            break
        end
        if not git commit -q -m "chore: sync local IDs for web issues" -- .beads/issues.jsonl
            echo "$c_warn""bd-pull: git commit failed$c_reset" >&2
            set rc 1
            break
        end

        # We don't even necessarily need to push, because the titles match.
        if set -q _flag_push
            if not git push
                echo "$c_warn""bd-pull: git push failed$c_reset" >&2
                set rc 1
            end
        else
            echo "$c_dim""Not pushed (use --push to push the commit).$c_reset"
        end
    end

    command rm -rf -- $tmp
    return $rc
end
