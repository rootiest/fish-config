status is-interactive || exit

# Local modification: opinionated guard (AGENTS.md Task #3). Puffer's key
# intercepts are part of the bang-bang system, gated atomically under C3
# overrides with conf.d/tricks.fish, conf.d/abbr.fish, and expand_*.fish.
__fish_config_op_enabled __fish_config_op_overrides || exit

function _puffer_fish_key_bindings --on-variable fish_key_bindings
    set -l modes
    if test "$fish_key_bindings" = fish_default_key_bindings
        set modes default insert
    else
        set modes insert default
    end

    bind --mode $modes[1] '.' _puffer_fish_expand_dot
    bind --mode $modes[1] '!' _puffer_fish_expand_bang
    bind --mode $modes[1] '$' _puffer_fish_expand_buck
    bind --mode $modes[1] '*' _puffer_fish_expand_star
    bind --mode $modes[2] --erase '.' '!' '$' '*'
end

_puffer_fish_key_bindings

set -l uninstall_event puffer_fish_key_bindings_uninstall

function _$uninstall_event --on-event $uninstall_event
    bind -e '.'
    bind -e '!'
    bind -e '$'
    bind -e '*'
end
