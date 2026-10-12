#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Invisible-Unicode lint (issue #256). No tracked text file may contain
#   - U+00A0 NO-BREAK SPACE      (UTF-8 C2 A0)
#   - U+200B ZERO WIDTH SPACE    (UTF-8 E2 80 8B)
#   - U+FEFF BYTE ORDER MARK     (UTF-8 EF BB BF), anywhere, including a BOM
# They are invisible in an editor, break a command if one lands in command
# position, and make grep/diff output confusing. Binary files are skipped.
#
# Runs isolated (no `# MODE:` marker). Pure text inspection plus a mktemp -d
# sandbox for the negative cases.

source (realpath (dirname (status filename)))/lib.fish

# The byte sequences, as a PCRE matched in the C locale so it works on raw
# bytes whatever the caller's locale.
set -g __iu_pattern '\xC2\xA0|\xE2\x80\x8B|\xEF\xBB\xBF'

# __iu_scan ROOT FILE...: `path:line` for every line of a FILE (relative to
# ROOT) that holds one of the characters. Binary files are skipped (-I).
function __iu_scan --argument-names root
    set -l files $argv[2..]
    set -q files[1]; or return 0
    command env LC_ALL=C grep -nIP -- $__iu_pattern (string replace -r '^' "$root/" -- $files) 2>/dev/null \
        | string replace "$root/" '' \
        | string replace -r '^([^:]+:[0-9]+):.*$' '$1'
    return 0
end

# Every tracked file, relative to ROOT. Falls back to find outside a git
# checkout (an exported tree, a CI copy).
function __iu_tracked --argument-names root
    set -l out (command git -C $root ls-files 2>/dev/null)
    if test (count $out) -eq 0
        set out (command find $root -type f -not -path "$root/.git/*" | string replace "$root/" '' | sort)
    end
    printf '%s\n' $out
    return 0
end

# ---- the scanner, on a sandbox tree -------------------------------------
section "invisible-Unicode scanner (sandbox)"
set -l sb (path resolve (mktemp -d))
printf 'clean ascii\n' >$sb/clean.fish
printf 'caf\xc3\xa9 and \xe2\x94\x80 rules are fine\n' >$sb/utf8.fish
printf 'ok\n# a\xc2\xa0comment\n' >$sb/nbsp.fish
printf 'echo\xe2\x80\x8bhi\n' >$sb/zwsp.fish
printf '\xef\xbb\xbf# bom\n' >$sb/bom.fish
printf '\x00\x01\xc2\xa0binary\n' >$sb/blob.bin
set -l got (__iu_scan $sb clean.fish utf8.fish nbsp.fish zwsp.fish bom.fish blob.bin)
check "reports exactly the offending lines" "nbsp.fish:2 zwsp.fish:1 bom.fish:1" "$got"
check "ordinary non-ASCII UTF-8 is not flagged" false (contains -- utf8.fish:1 $got; and echo true; or echo false)
check "binary files are skipped" 0 (count (string match 'blob.bin*' -- $got))
check "no files, no output" 0 (count (__iu_scan $sb))
command rm -rf $sb

# ---- the rule, on this tree ---------------------------------------------
section "tracked files: no invisible Unicode"
set -l tracked (__iu_tracked $repo_root)
check "tracked files were found" true (test (count $tracked) -gt 100; and echo true; or echo false)
set -l hits (__iu_scan $repo_root $tracked)
check "no tracked file contains U+00A0, U+200B or U+FEFF" 0 (count $hits)
for h in $hits
    echo "        found: $h"
end

report
