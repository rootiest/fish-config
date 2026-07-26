# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# SYNOPSIS
#   scrub [-a] [-d] [-h]
#
# DESCRIPTION
#   Recursively finds and removes OS metadata, editor artifacts, compiler
#   garbage, and dev caches from the current directory using fd. Routes
#   deletions through the custom rm function, trashy, trash-cli, or system
#   rm -rf in that priority order. Aggressive mode adds node_modules, logs,
#   IDE directories, and AI tool artifacts.
#
# ARGUMENTS
#   -a, --aggressive  Also purge node_modules, *.log, .cache, .idea, AI artifacts
#   -d, --dry-run     Show targets without deleting
#   -h, --help        Show usage help
#
# EXIT STATUS
#   0  Sweep completed (or dry run shown)
#   1  fd not found, or unknown argument provided
#
# EXAMPLE
#   scrub
#   scrub -a
#   scrub -d
function scrub --description 'Recursively purge OS, editor, and compiler garbage files/folders from the current directory'
    # Define the base garbage patterns (matches files and directory names)
    set -l garbage_patterns \
        '^\.DS_Store$' \
        '^\._.*' \
        '^Thumbs\.db$' \
        '^\.directory$' \
        '.*\.swp$' \
        '.*\.swo$' \
        '^\.netrwhist$' \
        '^\.pytest_cache$' \
        '^__pycache__$' \
        '.*-debug\.log$' \
        '^\.turbo$' \
        '.*\.gcode\.(tmp|bak)$' \
        '^\.bambu_bak$' \
        '^core\.[0-9]+$'

    # Define deep-cleaning aggressive patterns
    set -l aggressive_patterns \
        '.*\.class$' \
        '^\.git-crypt$' \
        '.*\.log$' \
        '.*\.log\.[0-9]+$' \
        '^node_modules$' \
        '^\.vagrant$' \
        '^\.clwb$' \
        '^\.idea$' \
        '^Thumbs\.db:encryptable$'
    '^\.gemini.*' \
        '^\.claude.*' \
        '^\.antigravity.*' \
        '^\.remember.*'

    # Helper function for help menu text
    function _scrub_help
        echo (set_color --bold cyan)"Usage:"(set_color normal) "scrub [options]"
        echo
        echo (set_color --bold cyan)"Options:"(set_color normal)
        echo "  -a, --aggressive Purge advanced development artifacts, logs, and heavyweight caches"
        echo "  -d, --dry-run    Show files/folders that would be targeted without removing them"
        echo "  -h, --help       Display this help menu"
        echo
        echo (set_color --bold cyan)"Standard Targets:"(set_color normal)
        echo "  • OS Metadata:   .DS_Store, ._* (AppleDouble), Thumbs.db, .directory (KDE)"
        echo "  • Editors:       *.swp, *.swo (Vim/Nvim), .netrwhist"
        echo "  • Dev Caches:    __pycache__, .pytest_cache, .turbo, *-debug.log"
        echo "  • Compiles:      core.[0-9]+ (Linux core dumps)"
        echo "  • Slicers:       *.gcode.tmp, *.gcode.bak, .bambu_bak"
        echo
        echo (set_color --bold yellow)"Aggressive Targets:"(set_color normal)
        echo "  • Heavy Caches:  node_modules, .vagrant"
        echo "  • Extra Cruft:   *.class, *.log, *.log.[0-9]+, Thumbs.db:encryptable"
        echo "  • IDE/Git Junk:  .idea, .clwb, .git-crypt"
        echo "  • AI/LLM Local:  .gemini*, .claude*, .antigravity*, .remember*"
    end

    # Parse arguments safely
    set -l dry_run 0
    set -l aggressive 0

    for arg in $argv
        switch $arg
            case -h --help
                _scrub_help
                return 0
            case -d --dry-run
                set dry_run 1
            case -a --aggressive
                set aggressive 1
            case '*'
                echo (set_color red)"Error: Unknown argument '$arg'"(set_color normal)
                _scrub_help
                return 1
        end
    end

    # If aggressive mode is flagged, merge the array targets seamlessly
    if test $aggressive -eq 1
        set garbage_patterns $garbage_patterns $aggressive_patterns
    end

    # Core dependency verification
    if not command -s fd >/dev/null
        echo (set_color --bold red)"Error:"(set_color normal) "Required tool "(set_color --underline)"fd"(set_color normal)" is missing."
        return 1
    end

    # Determine deletion method strategy hierarchy
    set -l delete_mode ""

    if functions -q rm
        set delete_mode custom_rm
    else if command -s trash >/dev/null
        set delete_mode trashy
    else if command -s trash-put >/dev/null
        set delete_mode trash_cli
    else
        set delete_mode fallback_rm
    end

    # --- Dry Run Mode ---
    if test $dry_run -eq 1
        if test $aggressive -eq 1
            echo (set_color --bold red)"⚡ Aggressive Dry Run Mode: Scanning deep tree..."(set_color normal)
        else
            echo (set_color --bold yellow)"⚡ Dry Run Mode: Scanning standard tree..."(set_color normal)
        end

        switch $delete_mode
            case custom_rm
                echo (set_color --dim normal)"[Strategy: Custom rm function]"(set_color normal)
            case trashy
                echo (set_color --dim normal)"[Strategy: trashy (trash put)]"(set_color normal)
            case trash_cli
                echo (set_color --dim normal)"[Strategy: trash-cli (trash-put)]"(set_color normal)
            case fallback_rm
                echo (set_color --dim normal)"[Strategy: System rm -rf (fallback)]"(set_color normal)
        end
        echo

        set -l found_any 0
        for pattern in $garbage_patterns
            set -l matches (fd --hidden --no-ignore $pattern)
            if count $matches >/dev/null
                set found_any 1
                for item in $matches
                    echo (set_color red)"  🗙 $item"(set_color normal)
                end
            end
        end

        if test $found_any -eq 0
            echo (set_color green)"✨ No garbage targets found. Everything looks clean."(set_color normal)
        end
        return 0
    end

    # --- Purge Mode ---
    if test $aggressive -eq 1
        echo (set_color --bold red)"🔥 Initiating AGGRESSIVE sweep..."(set_color normal)
    else
        echo (set_color --bold cyan)"🧹 Initiating sweep..."(set_color normal)
    end
    set -l count 0

    for pattern in $garbage_patterns
        set -l items (fd --hidden --no-ignore $pattern)

        if count $items >/dev/null
            for item in $items
                # Execute based on the resolved deletion strategy
                switch $delete_mode
                    case custom_rm
                        rm $item
                    case trashy
                        trash put $item
                    case trash_cli
                        trash-put $item
                    case fallback_rm
                        command rm -rf $item
                end

                echo (set_color --dim white)"  [purged] $item"(set_color normal)
                set count (math $count + 1)
            end
        end
    end

    echo
    if test $count -gt 0
        switch $delete_mode
            case custom_rm
                echo (set_color --bold green)"✔ Clean Sweep:"(set_color normal) "Safely processed" (set_color --bold yellow)$count(set_color normal) "target(s) using smart-rm."
            case trashy
                echo (set_color --bold green)"✔ Clean Sweep:"(set_color normal) "Safely moved" (set_color --bold yellow)$count(set_color normal) "target(s) to the system trash via trashy."
            case trash_cli
                echo (set_color --bold green)"✔ Clean Sweep:"(set_color normal) "Safely moved" (set_color --bold yellow)$count(set_color normal) "target(s) to the system trash via trash-put."
            case fallback_rm
                echo (set_color --bold red)"⚠ Hard Purge:"(set_color normal) "Permanently deleted" (set_color --bold yellow)$count(set_color normal) "target(s) via native rm -rf."
        end
    else
        echo (set_color --bold green)"✨ Clean Sweep:"(set_color normal) "No garbage targets found. Environment is pristine."
    end
end
