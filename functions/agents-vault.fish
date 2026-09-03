# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# DEPENDENCIES
#   _agents_vault_dir, _agents_repo_slug, _agents_repo_ensure_symlink,
#   _agents_repo_sync, _agents_repo_install_tools, git, hostname
#
# SYNOPSIS
#   agents-vault [--link] [--push] [--restore] [--status]
#                [--adopt=SLUG] [--remote=URL]
#                [-v | --verbose] [-q | --quiet] [-s | --silent]
#                [-h | --help]
#
# DESCRIPTION
#   Tracks curated agent memory in a host-scoped git repository so it
#   survives losing a machine. Complements agents-init, which scaffolds the
#   per-project AGENTS/ repo: that holds the shareable agent specification,
#   while this holds the personal memory an agent accumulates.
#
#   Memory does not live in any project tree. Claude keeps it under
#   ~/.claude/projects/<mangled-path>/memory/ and agy keeps its knowledge
#   store under ~/.gemini/antigravity-cli/, both outside every repository.
#
#   Entries are keyed by normalized git remote URL rather than by path, so
#   the key survives a machine change or a directory rename. The live
#   memory directory becomes a symlink into the vault, which makes backup
#   and restore the same operation: on a new machine, clone the vault once
#   and the first agents-vault run in any project relinks its memory
#   automatically. No manifest and no batch restore step are involved.
#
#   Only curated memory is tracked. Session transcripts are excluded (tens
#   of megabytes per project, growing per session). Paths are allowlisted,
#   never denylisted, so nothing new upstream adds can leak in.
#
# ARGUMENTS
#   --link         Scaffold the vault and link this project's memory; skip
#                  the final commit
#   --push         Commit and push to the vault remote
#   --restore      Walk the vault, relink what is possible, report the rest
#   --status       Show entries, link health, remote state, and orphans
#   --adopt=SLUG   Bind the current project to an existing vault entry
#   --remote=URL   Set the vault remote
#   -v, --verbose  Print all per-step output (default)
#   -q, --quiet    Print one summary line only if changes were made
#   -s, --silent   Suppress all output; errors only
#   -h, --help     Show this help message and exit
#
# EXIT STATUS
#   0  Completed successfully
#   1  Fatal error (vault unavailable, git failure, ambiguous migration)
#
# EXAMPLE
#   agents-vault
#   agents-vault --status
#   agents-vault --remote=https://git.rootiest.dev/rootiest/agent-vault.git
#   agents-vault --push
#
# NOTES
#   Set __fish_agent_vault_dir to relocate the vault. Set
#   __fish_agent_vault_autopush to 1 to also push on wrapper launch;
#   it defaults to off so a backgrounded push can never hang or prompt
#   invisibly underneath a starting agent.
function agents-vault --description 'track curated agent memory in a host-scoped vault repo'
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold)
    set -l c_flag (set_color yellow)
    set -l c_ok (set_color green)
    set -l c_warn (set_color yellow)
    set -l c_err (set_color red)
    set -l c_reset (set_color normal)

    argparse h/help link push restore status 'adopt=' 'remote=' \
        v/verbose q/quiet s/silent -- $argv
    or return 1

    if set -q _flag_help
        echo "$c_head""Usage:$c_reset $c_cmd""agents-vault$c_reset $c_flag""[--link] [--push] [--restore] [--status] [--adopt=SLUG] [--remote=URL] [-v] [-q] [-s] [-h]$c_reset"
        echo
        echo "  Track curated agent memory in a host-scoped vault repository."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset       Show this help message"
        echo "  $c_flag--link$c_reset           Scaffold + link this project; skip the commit"
        echo "  $c_flag--push$c_reset           Commit and push to the vault remote"
        echo "  $c_flag--restore$c_reset        Relink everything possible, report the rest"
        echo "  $c_flag--status$c_reset         Show entries, link health, remote, orphans"
        echo "  $c_flag--adopt$c_reset=SLUG     Bind this project to an existing vault entry"
        echo "  $c_flag--remote$c_reset=URL     Set the vault remote"
        echo "  $c_flag-v$c_reset, $c_flag--verbose$c_reset    Print all per-step output (default)"
        echo "  $c_flag-q$c_reset, $c_flag--quiet$c_reset      Print one summary line only if changed"
        echo "  $c_flag-s$c_reset, $c_flag--silent$c_reset     Suppress all output; errors only"
        return 0
    end

    set -l verbose 1
    set -l quiet 0
    if set -q _flag_silent
        set verbose 0
    else if set -q _flag_quiet
        set verbose 0
        set quiet 1
    end

    if not type -q git
        echo "$c_err""agents-vault: git is required$c_reset" >&2
        return 1
    end

    set -l vault (_agents_vault_dir)
    set -l changed 0
    set -l did_init 0

    #   ────────────────────── ensure the vault repo ──────────────────────
    if not test -d "$vault"
        if not mkdir -p "$vault"
            echo "$c_err""agents-vault: could not create $vault$c_reset" >&2
            return 1
        end
        set changed 1
        set did_init 1
    end
    if not test -d "$vault/.git"
        git -C "$vault" init -q
        or begin
            echo "$c_err""agents-vault: git init failed in $vault$c_reset" >&2
            return 1
        end
        set changed 1
        set did_init 1
        test $verbose -eq 1; and echo "$c_ok→ Initialized vault repo at $vault$c_reset"
    end

    if not test -f "$vault/.version"
        echo 1.0.0 >"$vault/.version"
        set changed 1
    end

    if not test -f "$vault/.gitignore"
        printf '%s\n' \
            '# SQLite sidecars are never safe to commit mid-write.' \
            '*.db-wal' \
            '*.db-shm' >"$vault/.gitignore"
        set changed 1
    end

    if not test -f "$vault/README.md"
        printf '%s\n' \
            '# Agent Memory Vault' \
            '' \
            'Curated agent memory, tracked so it survives losing a machine.' \
            'Managed by `agents-vault` from rootiest/fish-config.' \
            '' \
            '## Restore' \
            '' \
            'Clone this repository to the path `agents-vault` resolves to' \
            '(`$XDG_DATA_HOME/agent-vault`, or `$__fish_agent_vault_dir`).' \
            'Then simply run `claude` in any project: the wrapper derives that' \
            "project's slug, finds its entry here, and relinks the live memory" \
            'directory automatically. There is no separate restore step.' \
            '' \
            'Entries are keyed by normalized git remote URL. A `local-*` key' \
            'belongs to a project with no remote and is machine-specific;' \
            'rebind one with `agents-vault --adopt=SLUG`.' >"$vault/README.md"
        set changed 1
    end

    set -l tools_msg (_agents_repo_install_tools "$vault")
    or begin
        echo "$c_err""agents-vault: could not install .agents-tools/ into $vault$c_reset" >&2
        return 1
    end
    if test -n "$tools_msg"
        set changed 1
        test $verbose -eq 1; and echo "$c_ok$tools_msg$c_reset"
    end

    set -l hp (git -C "$vault" config --local core.hooksPath 2>/dev/null)
    if test "$hp" != .agents-tools/hooks
        git -C "$vault" config --local core.hooksPath .agents-tools/hooks
        or begin
            echo "$c_err""agents-vault: could not set core.hooksPath in $vault$c_reset" >&2
            return 1
        end
        set changed 1
    end

    #   ─────────────────────── unimplemented modes ───────────────────────
    for f in _flag_push _flag_restore _flag_status _flag_adopt _flag_remote
        if set -q $f
            echo "$c_err""agents-vault: that mode is not implemented yet$c_reset" >&2
            return 1
        end
    end

    #   ──────────────────── link the current project ─────────────────────
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$root"
        set -l slug (_agents_repo_slug "$root")
        set -l entry "$vault/projects/$slug"
        set -l vmem "$entry/claude/memory"

        if not test -d "$vmem"
            if not mkdir -p "$vmem"
                echo "$c_err""agents-vault: could not create $vmem$c_reset" >&2
                return 1
            end
            set changed 1
        end

        set -l claude_root $__fish_agent_vault_claude_root
        test -n "$claude_root"; or set claude_root "$HOME/.claude/projects"
        set -l mangled (string replace -a '/' '-' -- "$root" | string replace -a '.' '-')
        set -l live "$claude_root/$mangled/memory"

        # Unconditional: this is the emergent-restore path. On a freshly
        # cloned vault, $vmem already exists (populated from the clone) and
        # $live does not exist yet -- skipping the link here would silently
        # leave the clone's memory unlinked and let a starting agent write
        # fresh, history-less memory instead. _agents_repo_ensure_symlink is
        # idempotent and makes its own parent directories, so there is
        # nothing this guard would protect that the helper does not already
        # handle on its own.
        set -l link_msg (_agents_repo_ensure_symlink "$live" "$vmem")
        set -l link_rc $status
        if test $link_rc -ne 0
            echo "$c_err""agents-vault: could not link $live$c_reset" >&2
            return 1
        end
        if test -n "$link_msg"
            set changed 1
            test $verbose -eq 1; and echo "$c_ok$link_msg$c_reset"
        end

        if not test -f "$entry/origin"
            set -l url (git -C "$root" remote get-url origin 2>/dev/null)
            test -n "$url"; or set url "(none)"
            set -l host ""
            if type -q hostname
                set host (hostname 2>/dev/null)
            end
            printf 'remote: %s\npath:   %s\nhost:   %s\n' \
                "$url" "$root" "$host" >"$entry/origin"
            set changed 1
        end
    end

    #   ───────────────────────────── commit ──────────────────────────────
    if not set -q _flag_link
        set -l msg "chore: sync agent memory vault"
        test $did_init -eq 1; and set msg "chore: initialize agent memory vault"
        set -l sync_out (_agents_repo_sync "$vault" "$msg")
        set -l sync_rc $status
        if test $sync_rc -eq 2
            echo "$c_warn""agents-vault: unresolved rebase conflict in the vault; nothing committed$c_reset" >&2
        else if test -n "$sync_out"
            set changed 1
            test $verbose -eq 1; and echo "$c_ok$sync_out$c_reset"
        end
    end

    if test $quiet -eq 1; and test $changed -eq 1
        if test $did_init -eq 1
            echo "$c_ok→ Initialized agent memory vault$c_reset"
        else
            echo "$c_ok→ Synced agent memory vault$c_reset"
        end
    end
end
