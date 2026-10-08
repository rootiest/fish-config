#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Table-driven coverage of the opinionated-component guard system:
# __fish_variable_check, __fish_config_op_cascade,
# __fish_config_op_registry_lookup and __fish_config_op_enabled.
#
# Runs isolated (no `# MODE:` marker, which means isolated): the driver gives
# this process temp XDG dirs and --no-config, so there is no loaded config and
# no universal variables. That is load-bearing in both directions --
#
#   * these cases `set -e` real guard variable names, including
#     __fish_config_op_logging and __fish_config_opinionated. Under a plain
#     `fish` those erase from the innermost scope holding the variable, which
#     for a user with the variable set universally means destroying a real
#     universal variable. The temp XDG_CONFIG_HOME is what makes that
#     impossible.
#   * the two `set -p` / `source` lines below are what make the FORK's code the
#     code under test. Their failure modes differ and the difference matters:
#     forgetting the fish_function_path prepend fails LOUDLY (the guard
#     functions are unresolvable under --no-config and a call exits 127, which
#     can never equal an expected 0/1/2/3, so every case turns red), while
#     forgetting the registry source fails SILENTLY (__fish_config_op_enabled
#     fail-opens on a missing entry, so a third of the table would pass for
#     entirely the wrong reason). Hence the explicit precondition below.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish

section "guards: preconditions"

check "the fork's registry is loaded" 65 (count $__fish_config_op_registry_keys)

section "__fish_variable_check: truthy"

for v in 1 true yes on y Y TRUE ON
    set -g __probe_v $v
    __fish_variable_check __probe_v
    check "truthy '$v' -> 0" 0 $status
end

section "__fish_variable_check: falsy"

for v in 0 false no off n OFF FALSE
    set -g __probe_v $v
    __fish_variable_check __probe_v
    check "falsy '$v' -> 1" 1 $status
end

section "__fish_variable_check: neither"

set -e __probe_v
__fish_variable_check __probe_v
check "unset -> 2" 2 $status

set -g __probe_v ""
__fish_variable_check __probe_v
check "empty string -> 2" 2 $status

set -g __probe_v banana
__fish_variable_check __probe_v
check "unrecognized -> 3" 3 $status

__fish_variable_check
check "no argument -> 2" 2 $status

set -g __probe_v a b
__fish_variable_check __probe_v
check "multi-element list -> 3" 3 $status
set -e __probe_v

section "cascade: category only"

# Invented variable names the real config can never set, so nothing ambient can
# perturb these -- only the C5 and master cases below need real names.
set -e __fish_config_opinionated __probe_cat __probe_cat_sub

__fish_config_op_cascade __probe_cat
check "all unset -> enabled" 0 $status

set -g __probe_cat 0
__fish_config_op_cascade __probe_cat
check "category falsy -> disabled" 1 $status

set -g __probe_cat 1
__fish_config_op_cascade __probe_cat
check "category truthy -> enabled" 0 $status

set -g __probe_cat garbage
__fish_config_op_cascade __probe_cat 2>/dev/null
check "category unrecognized defers to master -> enabled" 0 $status
set -e __probe_cat

section "cascade: subcategory beats category"

set -g __probe_cat 0
set -g __probe_cat_sub 1
__fish_config_op_cascade __probe_cat __probe_cat_sub
check "sub on, category off -> enabled" 0 $status

set -g __probe_cat 1
set -g __probe_cat_sub 0
__fish_config_op_cascade __probe_cat __probe_cat_sub
check "sub off, category on -> disabled" 1 $status

set -e __probe_cat_sub
set -g __probe_cat 0
__fish_config_op_cascade __probe_cat __probe_cat_sub
check "sub unset, category off -> disabled" 1 $status

set -g __probe_cat_sub garbage
__fish_config_op_cascade __probe_cat __probe_cat_sub 2>/dev/null
check "sub unrecognized defers, category off -> disabled" 1 $status
set -e __probe_cat __probe_cat_sub

__fish_config_op_cascade __probe_cat ""
check "empty subcategory argument -> category-only chain" 0 $status

section "cascade: the master is an off switch only"

set -g __fish_config_opinionated 0
__fish_config_op_cascade __probe_cat
check "master off, category unset -> disabled" 1 $status

set -g __probe_cat 1
__fish_config_op_cascade __probe_cat
check "master off, category on -> enabled" 0 $status
set -e __probe_cat

set -g __fish_config_opinionated 1
__fish_config_op_cascade __probe_cat
check "master on, category unset -> enabled" 0 $status

set -g __fish_config_opinionated garbage
__fish_config_op_cascade __probe_cat 2>/dev/null
check "master unrecognized, category unset -> enabled" 0 $status
set -e __fish_config_opinionated

section "cascade: C5 logging is opt-in"

# Uses the REAL __fish_config_op_logging name because the opt-in list lives
# inside the cascade keyed on it. C5 logging is opt-in by design (see
# docs/fish-config.md's "C5 -- Logging and Capture" section): unset or
# unrecognized means off, and the master switch cannot enable it. If any of
# these three fail, that is a regression in the guard itself, not the test.
set -e __fish_config_op_logging __fish_config_opinionated

__fish_config_op_cascade __fish_config_op_logging
check "C5 unset -> disabled" 1 $status

set -g __fish_config_opinionated 1
__fish_config_op_cascade __fish_config_op_logging
check "C5 unset + master truthy -> still disabled" 1 $status
set -e __fish_config_opinionated

set -g __fish_config_op_logging garbage
__fish_config_op_cascade __fish_config_op_logging 2>/dev/null
check "C5 unrecognized is not consent -> disabled" 1 $status

set -g __fish_config_op_logging on
__fish_config_op_cascade __fish_config_op_logging
check "C5 explicit truthy -> enabled" 0 $status

set -g __fish_config_op_logging off
__fish_config_op_cascade __fish_config_op_logging
check "C5 explicit falsy -> disabled" 1 $status
set -e __fish_config_op_logging

section "cascade: C5 subcategories inherit opt-in"

# The opt-in check reads chain[-1], which is always the CATEGORY variable, so
# nesting inherits "off unless explicit" with no per-subcategory special case.
set -e __fish_config_op_logging_terminal_capture

__fish_config_op_cascade __fish_config_op_logging __fish_config_op_logging_terminal_capture
check "C5 sub unset, C5 unset -> disabled" 1 $status

set -g __fish_config_op_logging_terminal_capture 1
__fish_config_op_cascade __fish_config_op_logging __fish_config_op_logging_terminal_capture
check "C5 sub explicit truthy -> enabled" 0 $status

set -g __fish_config_op_logging_terminal_capture 0
set -g __fish_config_op_logging on
__fish_config_op_cascade __fish_config_op_logging __fish_config_op_logging_terminal_capture
check "C5 sub falsy, C5 truthy -> disabled" 1 $status
set -e __fish_config_op_logging_terminal_capture __fish_config_op_logging

section "registry lookup"

__fish_config_op_registry_lookup cat "" >/dev/null
check "known unsited key found" 0 $status

set -l t (__fish_config_op_registry_lookup cat "")
check "cat's tags" aliases/filesystem "$t"

__fish_config_op_registry_lookup nosuchthing "" >/dev/null
check "unknown identity -> not found" 1 $status

set -l t2 (__fish_config_op_registry_lookup config cdpath)
check "sited key config:cdpath" overrides/environment "$t2"

# The key is the identity:site PAIR, not the identity alone.
__fish_config_op_registry_lookup cat wrongsite >/dev/null
check "known identity, wrong site -> not found" 1 $status

section "op_enabled: against the real registry"

set -e __fish_config_op_aliases __fish_config_op_aliases_filesystem
set -e __fish_config_opinionated

__fish_config_op_enabled cat
check "cat, nothing set -> enabled" 0 $status

__fish_config_op_enabled cat.fish
check "a .fish suffix is stripped" 0 $status

set -g __fish_config_op_aliases 0
__fish_config_op_enabled cat
check "cat, aliases off -> disabled" 1 $status

set -g __fish_config_op_aliases_filesystem 1
__fish_config_op_enabled cat
check "cat, aliases off but its subcategory on -> enabled" 0 $status
set -e __fish_config_op_aliases __fish_config_op_aliases_filesystem

# Fail-open: an unclassified identity, or one whose doc header has no
# # COMPONENT section, resolves to enabled. This is what keeps user-authored
# and third-party functions unaffected.
__fish_config_op_enabled __totally_unregistered somesite
check "no registry entry -> fail open" 0 $status

section "op_enabled: always/* and AND, via a synthetic registry"

# Why this fixture exists, so nobody deletes it as redundant:
#
# The generated registry has 65 entries, EVERY ONE carrying exactly one tag,
# and contains no always/on or always/off anywhere (measured 2026-09-07
# against conf.d/__fish_config_op_registry.fish). So three documented
# semantics -- always/off, always/on, and AND-across-tags -- have no reachable
# case in production data and would otherwise go completely untested.
#
# The registry is just two global lists, and in isolated mode nothing else in
# this process reads them, so overriding them is free.
set -g __fish_config_op_registry_keys "syn_on:" "syn_off:" "syn_and:" "syn_bare:" "syn_multi:"
set -g __fish_config_op_registry_values \
    always/on \
    always/off \
    "aliases/filesystem integrations/notifications" \
    aliases \
    "always/off always/on"

set -e __fish_config_op_aliases __fish_config_op_integrations __fish_config_opinionated

__fish_config_op_enabled syn_off
check "always/off -> disabled" 1 $status

set -g __fish_config_op_aliases 1
__fish_config_op_enabled syn_off
check "always/off ignores an enabled category" 1 $status
set -e __fish_config_op_aliases

__fish_config_op_enabled syn_on
check "always/on -> enabled" 0 $status

set -g __fish_config_op_aliases 0
__fish_config_op_enabled syn_on
check "always/on short-circuits a disabled category" 0 $status
set -e __fish_config_op_aliases

__fish_config_op_enabled syn_multi
check "always/off beats always/on" 1 $status

section "op_enabled: AND across tagged sub-categories"

__fish_config_op_enabled syn_and
check "both categories default -> enabled" 0 $status

set -g __fish_config_op_aliases 0
__fish_config_op_enabled syn_and
check "first tag's category off -> disabled" 1 $status
set -e __fish_config_op_aliases

set -g __fish_config_op_integrations 0
__fish_config_op_enabled syn_and
check "second tag's category off -> disabled" 1 $status
set -e __fish_config_op_integrations

set -g __fish_config_op_aliases 1
set -g __fish_config_op_integrations 1
__fish_config_op_enabled syn_and
check "both explicitly on -> enabled" 0 $status
set -e __fish_config_op_aliases __fish_config_op_integrations

section "op_enabled: a tag with no slash"

# Degenerate but harmless: with no '/', $parts[2] is empty and the derived
# subcategory name gets a trailing underscore. That name is simply always
# unset, so the chain falls through to the category. Pinned so a future reader
# does not mistake it for a bug.
__fish_config_op_enabled syn_bare
check "bare tag 'aliases' -> enabled by default" 0 $status

set -g __fish_config_op_aliases 0
__fish_config_op_enabled syn_bare
check "bare tag honors its category" 1 $status
set -e __fish_config_op_aliases

section "op_enabled: C5 through the guard"

# The path production code actually takes, as opposed to calling the cascade
# directly. Same rule: unset means off and the master cannot enable it.
set -g __fish_config_op_registry_keys "syn_log:"
set -g __fish_config_op_registry_values logging/terminal-capture
set -e __fish_config_op_logging __fish_config_op_logging_terminal_capture

__fish_config_op_enabled syn_log
check "C5-tagged component, nothing set -> disabled" 1 $status

set -g __fish_config_opinionated 1
__fish_config_op_enabled syn_log
check "C5-tagged component + master truthy -> still disabled" 1 $status
set -e __fish_config_opinionated

set -g __fish_config_op_logging 1
__fish_config_op_enabled syn_log
check "C5-tagged component + explicit C5 on -> enabled" 0 $status
set -e __fish_config_op_logging

section "unrecognized values: one-time stderr warning"

# Behaviour is pinned by the sections above (the 3 is ignored exactly as
# before); this section pins only the added warning. Global guard variables
# stand in for the user's, so no universal variable is ever touched.
set -e __fish_op_warned_values __fish_config_opinionated __fish_config_op_logging __fish_config_op_aliases
set -e __probe_cat __probe_cat_sub

set -l out (__fish_config_op_cascade __probe_cat 2>&1)
check "unset value -> no output" "" "$out"
for v in 1 off Yes N
    set -g __probe_cat $v
    set out (__fish_config_op_cascade __probe_cat 2>&1)
    check "valid '$v' -> no output" "" "$out"
end
check "valid values record nothing" 0 (count $__fish_op_warned_values)

set -g __probe_cat ture
set out (__fish_config_op_cascade __probe_cat 2>&1 >/dev/null | string collect)
check "typo warns on stderr" true (string match -q -- "*__probe_cat*is set to*ture*expected one of on/off/1/0/true/false/yes/no/y/n*ignoring*" $out; and echo true; or echo false)
set out (__fish_config_op_cascade __probe_cat 2>/dev/null)
check "nothing on stdout" "" "$out"
check "dedupe list names the variable" __probe_cat "$__fish_op_warned_values"

set out (__fish_config_op_cascade __probe_cat 2>&1)
check "second call in the same session is silent" "" "$out"
__fish_config_op_cascade __probe_cat 2>/dev/null
check "status unchanged on repeat (unrecognized defers -> enabled)" 0 $status

# A different variable still warns once; sub-category is named, not the category.
set -g __probe_cat_sub disabled
set out (__fish_config_op_cascade __probe_cat __probe_cat_sub 2>&1 >/dev/null | string collect)
check "second variable warns, naming it and its value" true (string match -q -- "*__probe_cat_sub*is set to*disabled*" $out; and echo true; or echo false)
check "already-warned category variable not repeated (one line only)" 1 (count (string split \n -- (string trim -- $out)))
check "dedupe list holds both" "__probe_cat __probe_cat_sub" "$__fish_op_warned_values"
set -e __probe_cat __probe_cat_sub

# Master switch typo: warned, still ignored (enabled).
set -e __fish_op_warned_values
set -g __fish_config_opinionated maybe
set out (__fish_config_op_cascade __probe_cat 2>&1 >/dev/null | string collect)
check "master typo warns" true (string match -q -- "*__fish_config_opinionated*is set to*maybe*" $out; and echo true; or echo false)
__fish_config_op_cascade __probe_cat 2>/dev/null
check "master typo still ignored -> enabled" 0 $status
set -e __fish_config_opinionated

# C5: warns, and the opt-in semantics are untouched (unrecognized -> off).
set -e __fish_op_warned_values
set -g __fish_config_op_logging ture
set out (__fish_config_op_cascade __fish_config_op_logging 2>&1 >/dev/null | string collect)
check "C5 typo warns" true (string match -q -- "*__fish_config_op_logging*is set to*ture*" $out; and echo true; or echo false)
__fish_config_op_cascade __fish_config_op_logging 2>/dev/null
check "C5 typo still means off" 1 $status
set -e __fish_config_op_logging

# Through the production entry point, for a non-opt-in category.
set -e __fish_op_warned_values
set -g __fish_config_op_registry_keys "syn_warn:"
set -g __fish_config_op_registry_values aliases/filesystem
set -g __fish_config_op_aliases disabled
set out (__fish_config_op_enabled syn_warn 2>&1 >/dev/null | string collect)
check "op_enabled names the category variable and value" true (string match -q -- "*__fish_config_op_aliases*is set to*disabled*" $out; and echo true; or echo false)
__fish_config_op_enabled syn_warn 2>/dev/null
check "op_enabled behaviour unchanged (typo -> default enabled)" 0 $status
set out (__fish_config_op_enabled syn_warn 2>&1)
check "op_enabled second call silent" "" "$out"
set -e __fish_config_op_aliases __fish_op_warned_values

report
