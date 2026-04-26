set -g theme_nerd_fonts yes
set -g theme_color_scheme catpuccin-mocha
set -g theme_display_user ssh
set -g default_user rootiest
set -g theme_display_cmd_duration yes
set -g theme_display_git_dirty yes
set -g theme_display_virtualenv yes
set -g theme_display_screen yes
set -g theme_display_docker_machine yes
set -g theme_display_docker_context yes
set -g theme_display_nix yes
set -g theme_display_k8s_context yes
set -g theme_display_k8s_namespace yes
set -g theme_display_aws_vault_profile yes

set -g fish_key_bindings fish_vi_key_bindings

set -g theme_nerd_fonts yes
set -g theme_color_scheme catpuccin-mocha
set -g theme_display_user ssh
set -g default_user rootiest

function bobthefish_colors -S -d 'Define a custom bobthefish color scheme'

    # optionally include a base color scheme...
    # ___bobthefish_colors default

    # then override everything you want! note that these must be defined with `set -x`
    set -x color_initial_segment_exit ffffff ce000f --bold
    set -x color_initial_segment_private ffffff 255e87
    set -x color_initial_segment_su ffffff 189303 --bold
    set -x color_initial_segment_jobs ffffff 255e87 --bold
    set -x color_path 45475a a6adc8
    set -x color_path_basename 45475a ffffff --bold
    set -x color_path_nowrite f37799 585b70
    set -x color_path_nowrite_basename f37799 585b70 --bold
    set -x color_repo 89d88b 585b70
    set -x color_repo_work_tree 45475a ffffff --bold
    set -x color_repo_dirty f3799a ffffff
    set -x color_repo_staged ebd391 45475a
    set -x color_vi_mode_default a6adc8 45475a --bold
    set -x color_vi_mode_insert 89d88b 45475a --bold
    set -x color_vi_mode_visual ebd391 45475a --bold
    set -x color_vagrant 48b4fb ffffff --bold
    set -x color_aws_vault
    set -x color_aws_vault_expired
    set -x color_username 585b70 74a8fc --bold
    set -x color_hostname 585b70 74a8fc
    set -x color_rvm f37799 585b70 --bold
    set -x color_virtualfish 89b4fa 585b70 --bold
    set -x color_virtualgo 89b4fa 585b70 --bold
    set -x color_desk 89b4fa 585b70 --bold
    set -x color_nix 89b4fa 585b70 --bold
end
