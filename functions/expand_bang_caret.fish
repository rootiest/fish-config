# Execute expand_bang_caret
function expand_bang_caret --description 'Execute expand_bang_caret'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled __fish_config_op_overrides; or return 1

    # Split the last history item into a list
    set -l tokens (string split -n ' ' -- $history[1])
    # tokens[1] is the command, tokens[2] is the first argument
    if set -q tokens[2]
        echo -- $tokens[2]
    end
end
