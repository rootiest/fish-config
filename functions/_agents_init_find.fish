# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_init_find <root> <find-expression>...
#
# DESCRIPTION
#   Runs find over <root> with the prune set agents-init discovery uses,
#   then applies <find-expression> to every entry that survives. Pruned:
#   dot-directories (.git, .claude, .github -- tool state, not scoped
#   project dirs), any AGENTS/ (a mirror, never a source), node_modules,
#   generated-output directories (build, dist, out, target -- an
#   instruction file there is a build artifact), and nested repositories,
#   submodules and worktrees (their own .git marks another project).
#   -mindepth 1 keeps <root> itself, which has a .git, from pruning the
#   whole walk.
#
#   Shared by agents-init (instruction-file discovery) and agents-cleanup
#   (symlinks into AGENTS/), so the two never disagree about which part of
#   the tree belongs to the project.
#
# ARGUMENTS
#   root             Absolute path to the project root
#   find-expression  find primaries applied to every unpruned entry; must
#                    carry its own action (for example -print)
#
# EXIT STATUS
#   0  find completed
#   1  No root given, or find failed
#
# RETURNS
#   Whatever <find-expression> prints.
#
# EXAMPLE
#   _agents_init_find /path/to/project \( -name AGENTS.md -o -name CLAUDE.md \) -print
#   _agents_init_find /path/to/project -type l -print
function _agents_init_find --argument-names root
    test -n "$root"; or return 1
    find "$root" -mindepth 1 \
        -type d \( -name '.*' -o -name AGENTS -o -name node_modules \
        -o -name build -o -name dist -o -name out -o -name target \
        -o -exec test -e '{}/.git' \; \) -prune -o \
        $argv[2..]
end
