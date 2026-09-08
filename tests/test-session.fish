# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: in-session
#
# Functional checks for foundational config behavior. Sourced by
# tests/run-tests.fish into a fully-loaded, sandboxed interactive fish
# session -- see that file for the sandbox setup. Assertions here are the
# ones that genuinely need a loaded config; anything testable against a
# single function belongs in an isolated suite instead.

section "session: environment"

check "XDG vars are all set" true (test -n "$XDG_CONFIG_HOME" -a -n "$XDG_CACHE_HOME" -a -n "$XDG_DATA_HOME" -a -n "$XDG_STATE_HOME"; and echo true; or echo false)
check "PATH includes ~/.local/bin" true (contains -- "$HOME/.local/bin" $PATH; and echo true; or echo false)
check "CDPATH includes ~/projects" true (contains -- "$HOME/projects" $CDPATH; and echo true; or echo false)
check "vi key bindings active" fish_vi_key_bindings "$fish_key_bindings"
check "abbreviations loaded" true (abbr -q n; and echo true; or echo false)
check "privacy variables set" true (test "$DO_NOT_TRACK" = 1 -a "$DISABLE_TELEMETRY" = 1; and echo true; or echo false)

section "session: functions"

set -l missing
for f in cat logs config-help fish-deps check_fish_deps config-settings
    functions -q $f; or set -a missing $f
end
check "core functions defined" "" "$missing"

check "exit is rewired to smart_exit" true (functions -q exit; and functions exit | string match -q '*smart_exit*'; and echo true; or echo false)
check "fish_greeting defined" true (functions -q fish_greeting; and echo true; or echo false)

set -l missing_vault
for f in agents-vault _agents_vault_dir _agents_repo_slug \
    _agents_repo_ensure_symlink _agents_repo_sync _agents_repo_install_tools
    functions -q $f; or set -a missing_vault $f
end
check "agents-vault functions defined" "" "$missing_vault"

# One assertion, not two, so this file maps 1:1 onto the fifteen test_*
# predicates it replaces and the suite's 15/15 baseline is preserved.
check "claude and agy wrappers call agents-vault" true (functions -q claude; and functions claude | string match -q '*agents-vault*'; and functions -q agy; and functions agy | string match -q '*agents-vault*'; and echo true; or echo false)

section "session: guards in a loaded session"

set -l tags (__fish_config_op_registry_lookup config cdpath)
check "registry lookup finds config:cdpath" overrides/environment "$tags"

set -l ptags (__fish_config_op_registry_lookup config privacy)
check "registry lookup finds config:privacy" overrides/privacy "$ptags"

__fish_config_op_enabled __fish_config_test_never_registered somesite
check "unregistered component fails open" 0 $status

section "session: vault dir override"

set -l saved
set -q __fish_agent_vault_dir; and set saved $__fish_agent_vault_dir
set -g __fish_agent_vault_dir /tmp/vault-override-check
set -l got (_agents_vault_dir)
set -e __fish_agent_vault_dir
test (count $saved) -gt 0; and set -g __fish_agent_vault_dir $saved
check "vault dir honors the override" /tmp/vault-override-check "$got"

section "session: conf.d guards are lazy in non-interactive scripts"

# A non-interactive shell must not load interactive-only conf.d work. The
# child inherits XDG_CONFIG_HOME from this sandboxed session, so it loads
# the same config under test. Each exit code names one regression.
#
# Assertion 5 (tailscale) is vacuously true where tailscale is not
# installed: conf.d/tailscale.fish returned early on `type -q tailscale`
# before this change, and completions/tailscale.fish does the same, so the
# function is absent either way. The test still cannot fail wrongly there
# -- it just stops proving anything about that one file. A positive
# "completions still work" check would need the binary present and would
# make the suite machine-dependent, so it stays out.
fish -c '
    abbr -q n; and exit 1
    functions -q fish_user_key_bindings; and exit 2
    functions -q expand_bang_all; and exit 3
    functions -q __fish_config_logging_changed; and exit 4
    functions -q __tailscale_perform_completion; and exit 5
    exit 0'
check "conf.d guards stay out of non-interactive scripts" 0 $status

# Positive counterpart to the assertion above: the guard must not over-fire.
check "fish_user_key_bindings still defined in-session" true (functions -q fish_user_key_bindings; and echo true; or echo false)
