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

report
