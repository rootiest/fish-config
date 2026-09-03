# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_repo_ensure_symlink <link> <target>
#
# DESCRIPTION
#   Idempotently makes <link> a symlink pointing at the directory <target>.
#
#   Only directories are ever linked. The agent file-editing tools resolve a
#   symlinked directory transparently but refuse to write through a
#   symlinked file, so linking a file would silently break every later edit;
#   a non-directory target is refused outright.
#
#   A missing target is refused rather than linked, because a dangling
#   memory/ symlink makes agent memory writes fail -- strictly worse than
#   having no backup at all.
#
#   When <link> is an existing real directory, its contents are copied into
#   <target> without clobbering (cp -n) before the directory is replaced by
#   the link, so adopting a populated live directory never overwrites the
#   copy already in the vault.
#
# ARGUMENTS
#   link    Path that should become the symlink
#   target  Existing directory the link should point at
#
# EXIT STATUS
#   0  Link is correct (created, repinned, or already right)
#   1  Refused (non-directory target, missing target, non-directory link) or
#      a copy, remove, or link operation failed
#
# RETURNS
#   A single "→ ..." progress line on stdout when something changed;
#   nothing at all when the link was already correct.
#
# EXAMPLE
#   _agents_repo_ensure_symlink ~/.claude/projects/-home-u-proj/memory \
#       ~/.local/share/agent-vault/projects/host-user-proj/claude/memory
function _agents_repo_ensure_symlink --argument-names link target
    test -n "$link" -a -n "$target"; or return 1

    if test -e "$target"; and not test -d "$target"
        echo "_agents_repo_ensure_symlink: refusing non-directory target: $target" >&2
        return 1
    end
    if not test -d "$target"
        echo "_agents_repo_ensure_symlink: target does not exist: $target" >&2
        return 1
    end

    if test -L "$link"
        set -l cur (path resolve "$link")
        set -l want (path resolve "$target")
        test "$cur" = "$want"; and return 0
        rm -f "$link"; or return 1
    else if test -d "$link"
        set -l contents (command ls -A "$link" 2>/dev/null)
        if test (count $contents) -gt 0
            command cp -rn "$link/." "$target/"; or return 1
        end
        rm -rf "$link"; or return 1
    else if test -e "$link"
        echo "_agents_repo_ensure_symlink: refusing to replace non-directory: $link" >&2
        return 1
    end

    mkdir -p (path dirname "$link"); or return 1
    ln -s "$target" "$link"; or return 1
    echo "→ Linked "(path basename "$link")" → $target"
end
