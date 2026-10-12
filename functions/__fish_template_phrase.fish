# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_phrase FILE KEY NAME
#
# DESCRIPTION
#   Prints template metadata KEY (PHRASE, SYNOPSIS, STATUS, EXAMPLE) with
#   its placeholders filled from the store: {name} is NAME, {key} the
#   setting's values joined by spaces, {each:key} joined by ", ", and
#   {keys:key} the part of each value before "=", joined by ", ".
#
# EXIT STATUS
#   0  Printed
#   1  The template has no KEY line
function __fish_template_phrase --argument-names file key name --description 'Fill a fish-template metadata phrase'
    set -l text (__fish_template_meta $file $key); or return 1
    set text (string replace -a -- '{name}' $name $text)
    for k in (string match -ar --groups-only -- '\{(?:each:|keys:)?([a-z_][a-z0-9_]*)\}' $text)
        set -l v __ftv_$k
        set -l vals $$v
        set text (string replace -a -- "{each:$k}" "$(string join ', ' -- $vals)" $text)
        set text (string replace -a -- "{keys:$k}" "$(string replace -r -- '=.*' '' $vals | string join ', ')" $text)
        set text (string replace -a -- "{$k}" "$(string join ' ' -- $vals)" $text)
    end
    echo $text
end
