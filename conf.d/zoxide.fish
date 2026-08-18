# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
# Adapted from icezyclon/zoxide.fish (MIT)
# Heavily customized for Fish 4.x compatibility and performance

# COMPONENT
#   aliases/filesystem

if status is-interactive

    if type -q zoxide

        # -------------
        # 'zoxide init fish' is very different for different versions of zoxide
        # to guarantee the same behavior we define these functions ourself,
        # especially because the apt package is so old
        # most of these functions were taken from https://github.com/ajeetdsouza/zoxide
        # from version 0.8.1

        if ! builtin functions -q _zoxide_cd
            if builtin functions -q cd
                builtin functions -c cd _zoxide_cd
            else
                alias _zoxide_cd='builtin cd'
            end
        end

        function _zoxide_hook --on-variable PWD
            test -z "$fish_private_mode"
            and command zoxide add -- (builtin pwd -L)
        end

        function z
            set argc (count $argv)
            if test $argc -eq 0
                _zoxide_cd $HOME
            else if test "$argv" = -
                _zoxide_cd -
            else
                # Check if the argument is a directory (respecting CDPATH)
                set -l is_dir 1
                if test -d $argv[-1]
                    set is_dir 0
                else if not string match -rq '^\.?\.?/' -- $argv[-1]
                    for i in $CDPATH
                        if test -n "$i" -a -d "$i/$argv[-1]"
                            set is_dir 0
                            break
                        end
                    end
                end

                if test $is_dir -eq 0
                    _zoxide_cd $argv[-1]
                else
                    set -l result (command zoxide query -- $argv)
                    and _zoxide_cd $result
                end
            end
        end

        function zi
            set -l result (command zoxide query -i -- $argv)
            and _zoxide_cd $result
        end

        # -------------

        # Shadowing cd with zoxide is opinionated (C1 aliasing); z and zi
        # remain available either way.
        if __fish_config_op_enabled (status basename)
            alias cd=z
        end

        # use custom completion
        complete -c z -f # disable files by default 
        complete -c z -x -a '(_zoxide_z_complete)'
    end

end

function _zoxide_uninstall --on-event zoxide_uninstall
    if alias | grep "alias cd z" >/dev/null
        functions -e cd
    end
    if builtin functions -q _zoxide_cd && not functions -q cd
        # restore old cd
        builtin functions -c _zoxide_cd cd
    end
end
