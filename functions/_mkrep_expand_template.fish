# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _mkrep_expand_template <template> <name> <user> [<server>]
#
# DESCRIPTION
#   Substitutes the {name}, {user} and {server} placeholders in a mkrep
#   remote-create template and prints the result, ready for eval. Each value
#   is shell-escaped (string escape) as it is inserted, so a directory named
#   a;touch X or a --name containing $(...) arrives in the command as one
#   literal word instead of being executed. Because the values are already
#   quoted, a template must not wrap a placeholder in quotes of its own.
#
#   All placeholders are replaced in a single pass: a value that happens to
#   spell another placeholder (a directory literally named {user}) is never
#   substituted a second time. {server} is replaced only when <server> is
#   non-empty; otherwise it is left as written.
#
# ARGUMENTS
#   template   The command template
#   name       Value for {name}
#   user       Value for {user}
#   server     Value for {server} (optional)
#
# RETURNS
#   The expanded command, on stdout
#
# EXIT STATUS
#   0  Always
function _mkrep_expand_template --argument-names template name user server
    # Park each placeholder behind a control-character sentinel first, then
    # swap the sentinels for the escaped values. Substituting the values
    # directly, one placeholder after another, would re-scan text that an
    # earlier value had just inserted. string escape renders a raw \x01 as
    # \cA, so no escaped value can contain a sentinel.
    set -l s (printf '\x01')
    set -l out (string replace -a '{name}' "$s""N$s" -- $template)
    set out (string replace -a '{user}' "$s""U$s" -- $out)
    set -l have_server 0
    if test -n "$server"
        set have_server 1
        set out (string replace -a '{server}' "$s""S$s" -- $out)
    end

    set out (string replace -a "$s""N$s" (string escape -- $name) -- $out)
    set out (string replace -a "$s""U$s" (string escape -- $user) -- $out)
    test $have_server -eq 1
    and set out (string replace -a "$s""S$s" (string escape -- $server) -- $out)

    printf '%s\n' $out
    return 0
end
