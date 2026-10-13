#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Shell-script lint (issue #332). Every tracked file with a sh/bash shebang,
# or a .sh/.bash extension, must pass `shellcheck -S warning`. PR #328
# cleared the existing findings; this keeps them cleared.
#
# Without shellcheck the suite skips with a notice, so a local run on a
# machine without it still passes. Under CI ($CI set) a missing shellcheck
# fails instead: the fish-ci image ships it, and a silent skip there would
# turn the gate off unnoticed.
#
# Runs isolated (no `# MODE:` marker).

source (realpath (dirname (status filename)))/lib.fish

# Tracked shell scripts, relative to the repo root. Vendored fish plugins and
# everything else without a sh/bash shebang are left out.
function __sc_scripts --argument-names root
    for f in (git -C $root ls-files)
        test -f $root/$f; or continue
        if string match -qr '\.(sh|bash)$' -- $f
            echo $f
            continue
        end
        read -l first <$root/$f 2>/dev/null
        if string match -qr '^#!\s*\S*(/|env\s+)(ba)?sh(\s|$)' -- "$first"
            echo $f
        end
    end
    return 0
end

section "shellcheck: tracked shell scripts"

set -l scripts (__sc_scripts $repo_root)
check "found shell scripts to lint" true (set -q scripts[1]; and echo true; or echo false)

if type -q shellcheck
    for f in $scripts
        set -l out (shellcheck -S warning $repo_root/$f 2>&1)
        set -l rc $status
        check "shellcheck -S warning: $f" 0 $rc
        test $rc -eq 0; or printf '        %s\n' $out
    end
else if set -q CI
    check "shellcheck available in CI" true false
else
    echo "  SKIP  shellcheck not available"
end

report
