# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │             Sponge Privacy Pattern Registration          │
#          ╰──────────────────────────────────────────────────────────╯
#
# Two-layer approach to keeping credentials out of shell history:
#
#   Layer 1 — Static patterns (registered as universal, persistent):
#     Covers structural signatures: auth flags, env var assignments,
#     credential-bearing URLs, Authorization headers, sshpass, etc.
#     Patterns are added idempotently; user additions are preserved.
#
#   Layer 2 — Dynamic secret values (registered as session globals):
#     On the first prompt (after secrets.fish has loaded), reads the
#     literal values of all exported variables whose names indicate
#     credentials (TOKEN, PASSWORD, SECRET, KEY, etc.) and adds them
#     as a session-scoped pattern overlay.  Refreshes automatically
#     each login, so rotated tokens never leave stale patterns behind.
#
#   Layer 3 — Per-command filter (sponge_filter_secrets):
#     Catches mid-session variables set after login — e.g. a token
#     exported interactively or sourced from a project .env file.
#
# To add your own persistent patterns:
#   set -U -a sponge_regex_patterns 'your-regex-here'

if not status is-interactive
    return
end

# Only register if sponge is loaded
if not set -q sponge_version
    return
end

#   ──────────────────── Layer 1: Static patterns ────────────────────

set -l _privacy_patterns

# Common auth flags with values: --password x, --token x, --passphrase x, --api-key x
set -a _privacy_patterns '--(?:password|passwd|passphrase|token|secret|api[-_]key)(?:\s+|=)\S+'

# Inline env var assignments with sensitive names: GITHUB_TOKEN=xxx, MY_API_KEY=abc
set -a _privacy_patterns '(?i)\b[A-Z][A-Z0-9_]*(?:PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|PRIVATE_KEY|ACCESS_KEY|AUTH_KEY|CREDENTIAL)[A-Z0-9_]*=\S+'

# Fish set with sensitive variable names: set -gx GITHUB_TOKEN xxx, set -U MY_SECRET yyy
set -a _privacy_patterns '(?i)set\s+-\S+\s+\S*(?:password|passwd|token|secret|api.?key|private.?key|access.?key|credential)\S*\s+\S+'

# URLs with embedded credentials: https://user:password@host
set -a _privacy_patterns 'https?://[^:@\s]+:[^@\s]+@'

# HTTP Authorization headers: curl -H "Authorization: Bearer xxx"
set -a _privacy_patterns 'curl\s.*[Aa]uthorization:'

# Basic auth flags: curl -u user:pass, wget --user user --password pass
set -a _privacy_patterns '(?:curl|wget)\s.*(?:-u|--user)\s+\S+:\S+'

# sshpass — exposes credentials as a CLI argument by design
set -a _privacy_patterns '\bsshpass\b'

# Docker login with inline password
set -a _privacy_patterns 'docker\s+login\s.*(?:-p|--password)\s+\S+'

# openssl passphrase arguments: -passin pass:xxx, -passout env:VAR
set -a _privacy_patterns 'openssl\s.*-pass(?:in|out)\s+\S+'

# Idempotent registration into universal sponge_regex_patterns
for _pattern in $_privacy_patterns
    if not contains -- $_pattern $sponge_regex_patterns
        set -U -a sponge_regex_patterns $_pattern
    end
end

#   ──────────── Layer 2: Dynamic secret values (session globals) ────────────

# Runs once on the first prompt — by which point config.fish and secrets.fish
# have fully loaded, so all secret env vars are in scope.
# Builds a session-scoped global that combines the universal static patterns
# with the literal values of any credential-holding env vars.  Globals shadow
# universals in Fish, so the combined list is what sponge sees for this session.
function __sponge_register_secret_values --on-event fish_prompt
    functions --erase __sponge_register_secret_values # run exactly once

    set -l secret_values

    set -l sensitive_vars (set --names --export | string match --regex -- \
        '(?i)(?:TOKEN|PASSWORD|PASSWD|SECRET|API[_-]KEY|PRIVATE[_-]KEY|ACCESS[_-]KEY|AUTH[_-]KEY|CREDENTIAL|KOPIA_PASSWORD)')

    for var in $sensitive_vars
        set -l value $$var
        # Skip empty, short, or path-like values
        test (string length -- $value) -gt 8; or continue
        string match --quiet --regex '^[/~]' -- $value; and continue
        set -a secret_values (string escape --style=regex -- $value)
    end

    if test (count $secret_values) -gt 0
        # Merge static universals + dynamic values into a session global
        set -g sponge_regex_patterns $sponge_regex_patterns $secret_values
    end
end

#   ──────────── Layer 3: Mid-session filter (sponge_filter_secrets) ─────────

# Catches credentials in variables exported after login (e.g. project .env files).
# Only register if not already in sponge_filters.
if functions --query sponge_filter_secrets
    if not contains -- sponge_filter_secrets $sponge_filters
        set -U -a sponge_filters sponge_filter_secrets
    end
end
