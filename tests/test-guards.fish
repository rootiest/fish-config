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
__fish_config_op_cascade __probe_cat
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
__fish_config_op_cascade __probe_cat __probe_cat_sub
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
__fish_config_op_cascade __probe_cat
check "master unrecognized, category unset -> enabled" 0 $status
set -e __fish_config_opinionated

section "cascade: C5 logging is opt-in"

# Uses the REAL __fish_config_op_logging name because the opt-in list lives
# inside the cascade keyed on it. AGENTS.md: "C5 is opt-in (do not 'fix' this)"
# -- unset or unrecognized means off, and the master switch cannot enable it.
# If any of these three fail, that is a real defect: record it in
# JOB-BRIEF-FINDINGS.md, do not repair the guard.
set -e __fish_config_op_logging __fish_config_opinionated

__fish_config_op_cascade __fish_config_op_logging
check "C5 unset -> disabled" 1 $status

set -g __fish_config_opinionated 1
__fish_config_op_cascade __fish_config_op_logging
check "C5 unset + master truthy -> still disabled" 1 $status
set -e __fish_config_opinionated

set -g __fish_config_op_logging garbage
__fish_config_op_cascade __fish_config_op_logging
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

report
