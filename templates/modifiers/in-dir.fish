# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  in-dir
# KIND      modifier
# ORDER     10
# APPLIES   command fallback sequence dispatcher
# SUMMARY   Run inside a fixed directory, then return to where you were
# PHRASE    inside {indir_dir}
# STATUS    1 if {indir_dir} cannot be entered

#   ─────────────────────────────── Settings ───────────────────────────────

# Directory to run in. (path, required)
set -l indir_dir

#   ────────────────────────── Fragment: prepare ───────────────────────────

set __ft_prev_dir $PWD
builtin cd $indir_dir; or return 1

#   ────────────────────────── Fragment: finally ───────────────────────────

set -q __ft_prev_dir[1]; and builtin cd $__ft_prev_dir
