#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Licence-header rule (AGENTS.md coding convention 1, CONTRIBUTING.md
# "Vendored files", issue #239). Every tracked .fish file under functions/,
# conf.d/, completions/, tests/ and scripts/, plus config.fish, must either
#   - carry `SPDX-License-Identifier` in its first 5 lines, or
#   - be covered by an [[annotations]] `path` entry in REUSE.toml (vendored
#     third-party files, whose provenance lives there instead of in the file).
# Also asserted: the REUSE.toml entries are well formed and live (no stale
# path), each licence it names has its text under LICENSES/, and the
# `# UNRESOLVED:` files (provenance not yet established) are tolerated but
# reported, and fail only once they are stale.
#
# Runs isolated (no `# MODE:` marker). Pure text inspection plus a mktemp -d
# sandbox for the negative cases; nothing here needs the `reuse` tool.

source (realpath (dirname (status filename)))/lib.fish

# The `path = [ ... ]` entries of a REUSE.toml, one per line of output. The
# file keeps one quoted entry per line (stated in REUSE.toml itself).
function __lh_patterns --argument-names toml
    set -l in_path 0
    for line in (command cat $toml)
        if string match -qr '^path\s*=\s*\[\s*$' -- "$line"
            set in_path 1
        else if test $in_path -eq 1
            if string match -qr '^\s*\]' -- "$line"
                set in_path 0
            else
                string match -rg '^\s*"([^"]+)"\s*,?\s*$' -- "$line"
            end
        end
    end
    return 0
end

# REUSE glob -> anchored regex: `*` stays inside one path segment, `**`
# crosses directories, everything else is literal.
function __lh_glob_to_regex --argument-names glob
    set -l r (string escape --style=regex -- $glob)
    set r (string replace -a '\*\*' '.*' -- $r)
    set r (string replace -a '\*' '[^/]*' -- $r)
    echo "^$r\$"
end

# __lh_covered FILE REGEX...: 0 when any REGEX matches FILE.
function __lh_covered --argument-names file
    for re in $argv[2..]
        if string match -qr -- $re "$file"
            return 0
        end
    end
    return 1
end

# __lh_uncovered ROOT TOML FILE...: the FILEs (relative to ROOT) that have no
# SPDX-License-Identifier in their first 5 lines and match no TOML path.
function __lh_uncovered --argument-names root toml
    set -l res
    for g in (__lh_patterns $toml)
        set -a res (__lh_glob_to_regex $g)
    end
    for f in $argv[3..]
        if command head -n 5 -- "$root/$f" | string match -q '*SPDX-License-Identifier*'
            continue
        end
        if __lh_covered $f $res
            continue
        end
        echo $f
    end
    return 0
end

# Every tracked file, relative to ROOT. Falls back to find outside a git
# checkout (an exported tree, a CI copy).
function __lh_tracked --argument-names root
    set -l out (command git -C $root ls-files 2>/dev/null)
    if test (count $out) -eq 0
        set out (command find $root -type f -not -path "$root/.git/*" | string replace "$root/" '' | sort)
    end
    printf '%s\n' $out
    return 0
end

set -l toml $repo_root/REUSE.toml
set -l toml_lines (command cat $toml)
set -l tracked (__lh_tracked $repo_root)
set -l scoped (printf '%s\n' $tracked | string match -r '^(?:config\.fish|(?:functions|conf\.d|completions|tests|scripts)/.*\.fish)$')
set -l unresolved (string match -rg '^# UNRESOLVED: (\S+)\s*$' -- $toml_lines)
set -l all_res
for g in (__lh_patterns $toml)
    set -a all_res (__lh_glob_to_regex $g)
end

# ---- the matcher itself -----------------------------------------------------
section "REUSE glob matching"
set -l re (__lh_glob_to_regex 'functions/_autopair_*.fish')
check "* matches within a segment" 0 (__lh_covered functions/_autopair_tab.fish $re; echo $status)
check "* does not cross a directory" 1 (__lh_covered functions/_autopair_x/y.fish $re; echo $status)
check "a literal . is not a wildcard" 1 (__lh_covered functions/_autopair_tabXfish $re; echo $status)
check "the pattern is anchored at the start" 1 (__lh_covered xfunctions/_autopair_tab.fish $re; echo $status)
check "the pattern is anchored at the end" 1 (__lh_covered functions/_autopair_tab.fish.bak $re; echo $status)
set re (__lh_glob_to_regex 'scripts/**')
check "** crosses directories" 0 (__lh_covered scripts/a/b/c.fish $re; echo $status)
set re (__lh_glob_to_regex conf.d/done.fish)
check "an explicit path matches itself" 0 (__lh_covered conf.d/done.fish $re; echo $status)
check "an explicit path does not match a sibling" 1 (__lh_covered conf.d/fzf.fish $re; echo $status)

# ---- the rule, on a sandbox tree -------------------------------------------
section "header-or-REUSE rule (sandbox)"
set -l sb (path resolve (mktemp -d))
command mkdir -p $sb/functions
printf '# Copyright (C) 2026 Rootiest\n# SPDX-License-Identifier: AGPL-3.0-or-later\n\nfunction a\nend\n' >$sb/functions/headed.fish
printf 'function bare\nend\n' >$sb/functions/bare.fish
printf 'function vendored\nend\n' >$sb/functions/vendored.fish
printf 'function g\nend\n' >$sb/functions/glob_one.fish
printf '#\n#\n#\n#\n#\n# SPDX-License-Identifier: MIT\n' >$sb/functions/late.fish
printf 'version = 1\n\n[[annotations]]\npath = [\n  "functions/vendored.fish",\n  "functions/glob_*.fish",\n]\nprecedence = "closest"\nSPDX-FileCopyrightText = "x"\nSPDX-License-Identifier = "MIT"\n' >$sb/REUSE.toml
set -l sb_files functions/headed.fish functions/bare.fish functions/vendored.fish functions/glob_one.fish functions/late.fish
set -l got (__lh_uncovered $sb $sb/REUSE.toml $sb_files)
check "reports exactly the unheaded, unlisted files" "functions/bare.fish functions/late.fish" "$got"
check "an SPDX line past line 5 does not count as a header" true (contains -- functions/late.fish $got; and echo true; or echo false)
check "a header satisfies the rule" false (contains -- functions/headed.fish $got; and echo true; or echo false)
check "an explicit REUSE.toml path satisfies the rule" false (contains -- functions/vendored.fish $got; and echo true; or echo false)
check "a REUSE.toml glob satisfies the rule" false (contains -- functions/glob_one.fish $got; and echo true; or echo false)
printf 'version = 1\n\n[[annotations]]\npath = [\n  "functions/bare.fish",\n]\nprecedence = "closest"\nSPDX-FileCopyrightText = "x"\nSPDX-License-Identifier = "MIT"\n' >$sb/REUSE.toml
set got (__lh_uncovered $sb $sb/REUSE.toml $sb_files)
check "adding the path to REUSE.toml clears the report" "functions/vendored.fish functions/glob_one.fish functions/late.fish" "$got"
command rm -rf $sb

# ---- REUSE.toml is well formed ---------------------------------------------
section "REUSE.toml structure"
set -l n_ann (count (string match -r '^\[\[annotations\]\]$' -- $toml_lines))
check "declares version = 1" 1 (count (string match -r '^version = 1$' -- $toml_lines))
check "has at least one annotation" true (test $n_ann -gt 0; and echo true; or echo false)
check "every annotation has a multi-line path array" $n_ann (count (string match -r '^path = \[$' -- $toml_lines))
check "no path is written any other way" $n_ann (count (string match -r '^path\s*=' -- $toml_lines))
check "every annotation has a precedence" $n_ann (count (string match -r '^precedence = "(?:closest|aggregate|override)"$' -- $toml_lines))
check "every annotation has a licence" $n_ann (count (string match -r '^SPDX-License-Identifier = ' -- $toml_lines))
check "every annotation has a copyright text" $n_ann (count (string match -r '^SPDX-FileCopyrightText = ' -- $toml_lines))
for id in (string match -rg '^SPDX-License-Identifier = "([^"]+)"$' -- $toml_lines | sort -u)
    check "LICENSES/$id.txt exists" true (test -s $repo_root/LICENSES/$id.txt; and echo true; or echo false)
end

# ---- every REUSE.toml entry points at something --------------------------
section "REUSE.toml entries are live"
for g in (__lh_patterns $toml)
    set -l hits (printf '%s\n' $tracked | string match -r -- (__lh_glob_to_regex $g))
    check "matches a tracked file: $g" true (test (count $hits) -gt 0; and echo true; or echo false)
end

# ---- the rule, on this tree --------------------------------------------------
section "tracked .fish files: header or REUSE.toml entry"
check "in-scope files were found" true (test (count $scoped) -gt 100; and echo true; or echo false)
set -l uncovered (__lh_uncovered $repo_root $toml $scoped)
set -l unexpected
for f in $uncovered
    contains -- $f $unresolved; or set -a unexpected $f
end
check "every in-scope file has a header or a REUSE.toml entry" 0 (count $unexpected)
for f in $unexpected
    echo "        missing: $f"
end

# ---- unresolved list: tolerated, reported, never stale ------------------
# The section prints only when something is listed, so an empty list stays quiet.
if set -q unresolved[1]
    section "unresolved provenance (tolerated, needs maintainer confirmation)"
end
for f in $unresolved
    check "listed file exists: $f" true (contains -- $f $tracked; and echo true; or echo false)
    check "listed file is not also annotated: $f" 1 (__lh_covered $f $all_res; echo $status)
    check "listed file still lacks a header (else drop it from the list): $f" false (command head -n 5 -- $repo_root/$f | string match -q '*SPDX-License-Identifier*'; and echo true; or echo false)
    echo "  NOTE  unresolved, needs maintainer confirmation: $f"
end

report
