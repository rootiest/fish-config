#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for templates/*.fish: each template is instantiated the way a
# user would (edit the settings, save as <name>.fish on the function path)
# and exercised against a stub binary in a --no-config fish.

source (realpath (dirname (status filename)))/lib.fish

# Instantiate allow-telemetry.fish for a stub command named tpl_probe. The
# stub prints what it received and exits 7 so status passthrough is visible.
# $unset replaces the wrap_unset value verbatim (may be empty).
function _allow_telemetry_probe --argument-names unset
    set -l tmp (mktemp -d)
    mkdir $tmp/bin $tmp/functions
    printf '%s\n' '#!/bin/sh' \
        'echo "DNT=[$DO_NOT_TRACK] DT=[$DISABLE_TELEMETRY] KEEP=[$KEEP] args=$*"' \
        'exit 7' >$tmp/bin/tpl_probe
    chmod +x $tmp/bin/tpl_probe
    string replace -r '^set -l wrap_cmd .*' 'set -l wrap_cmd tpl_probe' <$repo_root/templates/allow-telemetry.fish \
        | string replace -r '^set -l wrap_unset .*' "set -l wrap_unset $unset" >$tmp/functions/tpl_probe.fish
    env PATH=(string join : $tmp/bin $PATH) DO_NOT_TRACK=1 DISABLE_TELEMETRY=1 KEEP=1 fish --no-config -c \
        "set -g fish_function_path $tmp/functions \$fish_function_path
         tpl_probe a 'b c'; echo status=\$status
         echo parent=\$DO_NOT_TRACK leak=(set -q wrap_cmd; and echo yes; or echo no)"
    rm -rf $tmp
end

section "templates: allow-telemetry"
set -l out (_allow_telemetry_probe "DO_NOT_TRACK DISABLE_TELEMETRY")
check "listed vars removed, others kept, args forwarded" "DNT=[] DT=[] KEEP=[1] args=a b c" "$out[1]"
check "exit status passes through" status=7 "$out[2]"
check "parent keeps vars, settings do not leak" "parent=1 leak=no" "$out[3]"

set -l out (_allow_telemetry_probe "")
check "empty unset list passes environment through" "DNT=[1] DT=[1] KEEP=[1] args=a b c" "$out[1]"

report
