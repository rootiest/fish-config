# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   bd-pull <owner/repo>
#
# DESCRIPTION
#   Fetches unlinked issues from a Gitea repository, creates corresponding local
#   Beads entries, and updates the Gitea issue titles to include the new Bead IDs.
#   Requires $GITEA_TOKEN and $GITEA_URL to be set.
#
# ARGUMENTS
#   owner/repo  The repository path in owner/name format
#
# RETURNS
#   0  Issues linked and synced (or no unlinked issues found)
#   1  Missing required argument or environment variables
#
# EXAMPLE
#   bd-pull myuser/myproject
function bd-pull --description 'Pull new Gitea issues into local Beads and link them'
    if not set -q argv[1]; echo "Need repo owner/name"; return 1; end
    if not set -q GITEA_TOKEN; echo "\$GITEA_TOKEN not set"; return 1; end

    set -l REPO $argv[1]
    if not set -q GITEA_URL; echo "\$GITEA_URL not set"; return 1; end
    set -l IMPORT_COUNT 0

    echo (set_color blue)"📡 Checking Gitea: $REPO..."(set_color normal)

    # 1. Fetch issues (using jq to get BOTH title and number)
    set -l gitea_json (curl -s -H "Authorization: token $GITEA_TOKEN" "$GITEA_URL/api/v1/repos/$REPO/issues?state=all")

    # 2. Iterate through issues using their index/number
    for row in (echo $gitea_json | jq -r '.[] | @base64')
        set -l _decode (echo $row | base64 --decode)
        set -l title (echo $_decode | jq -r '.title')
        set -l number (echo $_decode | jq -r '.number')

        # If it doesn't have [ID] brackets, it's a "Web-Original" issue
        if not string match -qr "^\[.*\]" "$title"
            echo (set_color yellow)"➕ Linking Web Issue #$number: $title"(set_color normal)
            
            # A. Create local Bead and capture the new ID
            # This captures the output of bd create to find the ID it generated
            set -l bd_output (bd create --title "$title")
            set -l bid (echo $bd_output | string match -r "bd-[a-z0-9]+" | head -n 1)
            
            if test -z "$bid"
                # Fallback: find the latest ID in the jsonl if regex fails
                set bid (tail -n 1 .beads/issues.jsonl | jq -r '.id')
            end

            # B. Update the Gitea Issue Title IMMEDIATELY via API
            # This prevents the Gitea Action from creating a duplicate
            set -l new_title "[$bid] $title"
            curl -s -X PATCH -H "Authorization: token $GITEA_TOKEN" \
                 -H "Content-Type: application/json" \
                 -d "{\"title\":\"$new_title\"}" \
                 "$GITEA_URL/api/v1/repos/$REPO/issues/$number" > /dev/null

            set IMPORT_COUNT (math $IMPORT_COUNT + 1)
        end
    end

    if test "$IMPORT_COUNT" -gt 0
        echo (set_color green)"✅ Linked $IMPORT_COUNT issues."(set_color normal)
        bd sync
        # We don't even necessarily need to push now, because the titles match!
        git add .beads/issues.jsonl
        git commit -m "chore: sync local IDs for web issues"
        git push
    else
        echo "⠿ No unlinked issues found."
    end
end
