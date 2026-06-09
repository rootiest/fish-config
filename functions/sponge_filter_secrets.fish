# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   sponge_filter_secrets <command> <exit_code> <previously_in_history>
#
# DESCRIPTION
#   Custom sponge filter that prevents commands from being stored in history
#   when they contain the literal value of any exported environment variable
#   whose name indicates it holds a credential (TOKEN, PASSWORD, SECRET,
#   API_KEY, etc.).  This catches shell-expansion leakage where a variable
#   value is embedded directly in the command string at execution time — a
#   case that static regex patterns cannot cover.
#
#   Any variable whose name matches the sensitive-name heuristic and whose
#   value is longer than 8 characters (excluding bare paths) is checked.
#   The value is escaped for literal regex matching before comparison.
#
# ARGUMENTS
#   command                 The exact command that was entered
#   exit_code               Exit code of the command (unused)
#   previously_in_history   "true"/"false" flag (unused)
#
# RETURNS
#   0  Command contains a secret value — filter out of history
#   1  No secret value found — keep in history
#
# EXAMPLE
#   # Register with sponge (done automatically by conf.d/sponge_privacy.fish):
#   set -U -a sponge_filters sponge_filter_secrets

function sponge_filter_secrets --argument-names command
    # Find all exported variables with security-sensitive names
    set -l sensitive_vars (set --names --export | string match --regex -- \
        '(?i)(?:TOKEN|PASSWORD|PASSWD|SECRET|API[_-]KEY|PRIVATE[_-]KEY|ACCESS[_-]KEY|AUTH[_-]KEY|CREDENTIAL|KOPIA_PASSWORD)')

    for var in $sensitive_vars
        set -l value $$var

        # Skip empty, short, or path-like values — not real credentials
        test (string length -- $value) -gt 8; or continue
        string match --quiet --regex '^[/~]' -- $value; and continue

        # Filter if the literal value appears anywhere in the command
        if string match --quiet --regex -- (string escape --style=regex -- $value) $command
            return 0
        end
    end

    return 1
end
