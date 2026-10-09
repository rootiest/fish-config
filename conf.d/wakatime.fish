###
# wakatime.fish
#
# hook script to send wakatime a tick (unofficial)
# see: https://github.com/ik11235/wakatime.fish
###

# COMPONENT
#   site wakatime-autoexec: autoexec/telemetry
#   site wakatime-hook: integrations/notifications

# Registers a fish_postexec handler; that event is emitted only by the
# interactive reader, so the handler is dead weight in a script.
status is-interactive; or return

# Local modification: opinionated guard (AGENTS.md Task #3). WakaTime
# reporting is classified under both C2 auto-execution and C4 integrations;
# disabling either category skips registering the hook.
__fish_config_op_enabled (status basename) wakatime-autoexec; or exit
__fish_config_op_enabled (status basename) wakatime-hook; or exit

#   ─────────────────── Local modification: resolve the CLI once ───────────────────
# The upstream handler ran `type -p` (and up to three git processes) on every
# command, installed or not. Here the CLI is resolved once and cached in
# $__wakatime_fish_bin, and the postexec handler is registered only when a CLI
# exists. conf.d runs before config.fish extends $PATH, so a CLI under
# ~/.local/bin (where fish-deps links it) may not be visible yet at source
# time: when the first lookup fails, a one-shot fish_prompt handler retries
# once $PATH is complete and then removes itself. With no CLI at all nothing
# stays registered, and commands pay nothing.

function __wakatime_fish_resolve
    set -l found
    if type -q wakatime
        set found (type -p wakatime)
    else if test -x ~/.wakatime/wakatime-cli
        set found ~/.wakatime/wakatime-cli
    end
    if test -z "$found"
        return 1
    end
    set -g __wakatime_fish_bin $found[1]
    return 0
end

# The per-command work. A plain function (no event), so defining it costs
# nothing; __wakatime_fish_enable wires it to fish_postexec.
function __wakatime_fish_tick
    # Opt-outs, checked per command so toggling them takes effect at once.
    if set -q FISH_WAKATIME_DISABLED
        return 0
    end
    # Honour the cross-tool telemetry opt-outs (the C3 privacy block in
    # config.fish exports both). __fish_variable_check is the shared
    # truthiness parser; these are not opinionated-component guards.
    # FISH_WAKATIME_IGNORE_DNT=1 is the per-machine override: WakaTime keeps
    # reporting while DO_NOT_TRACK / DISABLE_TELEMETRY stay exported (and
    # honoured) for every other tool.
    if not __fish_variable_check FISH_WAKATIME_IGNORE_DNT
        if __fish_variable_check DO_NOT_TRACK; or __fish_variable_check DISABLE_TELEMETRY
            return 0
        end
    end

    set -l exec_command_str (string split -f1 ' ' "$argv")

    if test "$exec_command_str" = exit
        return 0
    end

    set -l PLUGIN_NAME "ik11235/wakatime.fish"
    set -l PLUGIN_VERSION "0.0.6"

    # FISH_WAKATIME_PROJECT sends a constant project name instead of the
    # repository directory name (and skips the repository lookup entirely).
    set -l project
    if test -n "$FISH_WAKATIME_PROJECT"
        set project $FISH_WAKATIME_PROJECT
    else
        set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
        if test -n "$toplevel"
            set project (path basename $toplevel)
        else
            set project Terminal
        end
    end

    $__wakatime_fish_bin --write --plugin "$PLUGIN_NAME/$PLUGIN_VERSION" --entity-type app --project "$project" --entity "$exec_command_str" &>/dev/null &
    disown
    return 0
end

function __wakatime_fish_enable
    function __register_wakatime_fish_before_exec -e fish_postexec
        __wakatime_fish_tick $argv
    end
end

if __wakatime_fish_resolve
    __wakatime_fish_enable
else
    function __wakatime_fish_late_resolve -e fish_prompt
        functions -e __wakatime_fish_late_resolve
        if __wakatime_fish_resolve
            __wakatime_fish_enable
        end
    end
end
