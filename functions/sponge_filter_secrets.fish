# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   11-pager-and-logging
#
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
#   value is longer than 8 characters is checked.  List-valued variables are
#   handled: every element is checked.  Values that are an existing file or
#   directory path (a leading ~/ is expanded) are skipped; a value that merely
#   starts with / or ~ but is not an existing path is still treated as a
#   credential.  The value is escaped for literal regex matching before
#   comparison.
#
# ARGUMENTS
#   command                 The exact command that was entered
#   exit_code               Exit code of the command (unused)
#   previously_in_history   "true"/"false" flag (unused)
#
# EXIT STATUS
#   0  Command contains a secret value — filter out of history
#   1  No secret value found — keep in history
#
# EXAMPLE
#   # Register with sponge (done automatically by conf.d/sponge_privacy.fish):
#   set -U -a sponge_filters sponge_filter_secrets
function sponge_filter_secrets --argument-names command
    # Find all exported variables with security-sensitive names
    set -l sensitive_vars (set --names --export | string match --entire --regex -- \
        '(?i)(?:TOKEN|PASSWORD|PASSWD|SECRET|API[_-]KEY|PRIVATE[_-]KEY|ACCESS[_-]KEY|AUTH[_-]KEY|CREDENTIAL|KOPIA_PASSWORD)')

    for var in $sensitive_vars
        # Check every element: `$$var[1]` would index the inner name, not the
        # dereferenced list. An unset or empty variable simply loops zero times.
        for value in $$var
            # Skip short values — not real credentials
            test (string length -- $value) -gt 8; or continue

            # Skip values that are an existing file or directory (a leading ~/
            # is expanded). Anything else is a credential, even if it starts
            # with / or ~.
            test -e (string replace --regex -- '^~(?=/)' $HOME $value); and continue

            # Filter if the literal value appears anywhere in the command
            if string match --quiet --regex -- (string escape --style=regex -- $value) $command
                return 0
            end
        end
    end

    return 1
end
