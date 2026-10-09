# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_sponge_sensitive_pattern
#
# DESCRIPTION
#   Prints the one regular expression that decides which environment variable
#   NAMES count as credentials for the history-privacy system. It is the single
#   source shared by both dynamic layers: the session registration in
#   conf.d/sponge_privacy.fish (Layer 2) and the per-command filter
#   sponge_filter_secrets (Layer 3). Keeping them on one definition means a name
#   added through config-settings (Sponge page) is honoured by both.
#
#   The pattern is case-insensitive and matches a name that contains any of the
#   built-in tokens (TOKEN, PASSWORD, PASSWD, SECRET, API_KEY, PRIVATE_KEY,
#   ACCESS_KEY, AUTH_KEY, CREDENTIAL, KOPIA_PASSWORD) or any entry of
#   $__fish_sponge_extra_sensitive. Extra entries are used as regex fragments.
#
# EXIT STATUS
#   0  Always: the pattern is printed to stdout
#
# RETURNS
#   The name-matching regular expression, on one line
#
# EXAMPLE
#   set -l names (set --names --export | string match --regex --entire -- (__fish_sponge_sensitive_pattern))
function __fish_sponge_sensitive_pattern --description 'Print the regex matching credential-bearing variable names'
    set -l names \
        TOKEN PASSWORD PASSWD SECRET 'API[_-]KEY' 'PRIVATE[_-]KEY' \
        'ACCESS[_-]KEY' 'AUTH[_-]KEY' CREDENTIAL KOPIA_PASSWORD \
        $__fish_sponge_extra_sensitive
    echo "(?i)(?:"(string join '|' $names)")"
    return 0
end
