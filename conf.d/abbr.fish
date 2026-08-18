# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
#          ╭──────────────────────────────────────────────────────────╮
#          │                       Abreviations                       │
#          ╰──────────────────────────────────────────────────────────╯
#
# This file contains all the abbreviations for the terminal.
# It is sourced by Fish on startup.

# COMPONENT
#   site abbr-integrations: integrations/terminal-abbrs
#   site abbr-overrides: overrides/key-bindings

# Neovim
# @category Editors
# @desc nvim
abbr -a n nvim
# @category Editors
# @desc nvim
abbr -a nv nvim
# @category Editors
# @desc nvim
abbr -a neovim nvim
# @category Editors
# @desc cd ~/.config/nvim
abbr -a cdnv 'cd ~/.config/nvim # Neovim Config'
# @category Editors
# @desc cd ~/.config/nvim; nvim
abbr -a cdnvn 'cd ~/.config/nvim;nvim'
# VSCode
# @category AI Assistants
# @desc antigravity-ide
abbr -a v antigravity-ide
# Kate
# @category Editors
# @desc kate
abbr -a k kate
# WezTerm SSH
if test "$TERM_PROGRAM" = WezTerm
    # @category AI Assistants
    # @desc wezterm ssh (WezTerm only)
    abbr -a s wezterm ssh
end
# Neovim in a new tab
if test "$TERM" = xterm-kitty
    # @category Terminal Windows, Tabs, and Panes
    # @desc Open new tab with nvim (terminal-aware)
    abbr -a editt kitty @ launch --type=tab --cwd=current nvim # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    # @category Terminal Windows, Tabs, and Panes
    # @desc Open new tab with nvim (terminal-aware)
    abbr -a editt wezterm cli spawn nvim # WezTerm
end
# LazyGit
# @category Git
# @desc lazygit
abbr -a lg lazygit
# Sudo shell
# @category Miscellaneous
# @desc sudo -s
abbr -a sudu sudo -s
# Kitty
if test "$TERM" = xterm-kitty
    # @category Miscellaneous
    # @desc kitty (Kitty only)
    abbr -a kt kitty
end
# cat
# @category Miscellaneous
# @desc cat
abbr -a c cat
# chezmoi
# @category Chezmoi
# @desc chezmoi
abbr -a cm chezmoi
# chezmoi cd
# @category Chezmoi
# @desc chezmoi cd
abbr -a cmcd chezmoi cd
# @category Chezmoi
# @desc chezmoi cd
abbr -a czcd chezmoi cd
# @category Chezmoi
# @desc chezmoi cd
abbr -a cdcm chezmoi cd
# @category Chezmoi
# @desc chezmoi cd
abbr -a cdcz chezmoi cd
# chezmoi edit
# @category Chezmoi
# @desc chezmoi edit
abbr -a cme chezmoi edit
# @category Chezmoi
# @desc chezmoi edit
abbr -a cze chezmoi edit
# chezmoi add
# @category Chezmoi
# @desc chezmoi add
abbr -a cmad chezmoi add
# @category Chezmoi
# @desc chezmoi add
abbr -a czad chezmoi add
# chezmoi apply
# @category Chezmoi
# @desc chezmoi apply
abbr -a cmap chezmoi apply
# @category Chezmoi
# @desc chezmoi apply
abbr -a czap chezmoi apply
# chezmoi rm
# @category Chezmoi
# @desc chezmoi forget
abbr -a cmrm chezmoi forget
# @category Chezmoi
# @desc chezmoi forget
abbr -a cmf chezmoi forget
# @category Chezmoi
# @desc chezmoi forget
abbr -a czrm chezmoi forget
# @category Chezmoi
# @desc chezmoi forget
abbr -a czf chezmoi forget
# chezmoi init
# @category Chezmoi
# @desc chezmoi init
abbr -a cmi chezmoi init
# @category Chezmoi
# @desc chezmoi init
abbr -a czi chezmoi init
# Edit
# @category Editors
# @desc edit
abbr -a e edit
# Sudoedit
# @category Editors
# @desc sudoedit
abbr -a se sudoedit
# Git
# @category Git
# @desc git
abbr -a g git
# @category Git
# @desc generate .gitignore
abbr -a gitig gi
# @category Git
# @desc generate .gitignore
abbr -a git-ignore gi
# Antigravity
# @category AI Assistants
# @desc agy
abbr -a ag agy
# @category AI Assistants
# @desc agy .
abbr -a ag. agy .
# Quit
# @category Miscellaneous
# @desc exit
abbr -a /exit exit
# Window-management abbreviations are opinionated (C4 integrations)
if __fish_config_op_enabled (status basename) abbr-integrations
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Close current pane/window
        abbr -a :q kitty @ close-window # Kitty (Closes the active split/pane)
        # @category Terminal Windows, Tabs, and Panes
        # @desc Close current tab
        abbr -a :Q kitty @ close-tab # Kitty (Closes the whole tab)
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Close current pane/window
        abbr -a :q wezterm cli kill-pane # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Close current tab
        abbr -a :Q wezterm cli kill-pane # WezTerm
    end
end

######### Alternates ##########
### ls alternates
# List all files
# @category Navigation and Listing
# @desc ls
abbr -a l ls
# List all files by size
# @category Navigation and Listing
# @desc lss (sort by size)
abbr -a lS lss
# List all files by reverse modified time
# @category Navigation and Listing
# @desc lsr (sort by time, oldest first)
abbr -a lsR lsr
# List by extension
# @category Navigation and Listing
# @desc lx (sort by extension)
abbr -a lX lx
# Tree listing (depth 2)
# @category Navigation and Listing
# @desc lt (tree, depth 2)
abbr -a lT lt
# Full tree listing
# @category Navigation and Listing
# @desc lstree (full recursive tree)
abbr -a lsT lstree
### speed-test alternates
# Speedtest using fast.com
# @category Miscellaneous
# @desc fast-cli
abbr -a speedtest-fast fast-cli

# Kitty/WezTerm window-management abbreviations are opinionated (C4
# integrations): they assume an active Kitty or WezTerm session.
if __fish_config_op_enabled (status basename) abbr-integrations
    # Window Creation (OS Windows)
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window
        abbr -a :w kitty @ launch --type=os-window # Kitty
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window
        abbr -a :w wezterm cli spawn --new-window # WezTerm
    end

    # Window Splits (Panes)
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split pane horizontally (new pane below)
        abbr -a :wv kitty @ launch --location=hsplit # Kitty (Horizontal split)
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split pane vertically (new pane to the right)
        abbr -a :wh kitty @ launch --location=vsplit # Kitty (Vertical split)
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split pane horizontally (new pane below)
        abbr -a :wv wezterm cli split-pane --bottom # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split pane vertically (new pane to the right)
        abbr -a :wh wezterm cli split-pane --right # WezTerm
    end

    # Window Detach (Move Pane)
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Detach current window to its own OS window
        abbr -a :wo kitty @ detach-window --target-tab=new # Kitty (Moves pane to new tab)
        # @category Terminal Windows, Tabs, and Panes
        # @desc Move current pane to a new tab
        abbr -a :wot kitty @ detach-window # Kitty (Same as above, default behavior)
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Detach current window to its own OS window
        abbr -a :wo wezterm cli move-pane-to-new-tab --new-window # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Move current pane to a new tab
        abbr -a :wot wezterm cli move-pane-to-new-tab # WezTerm
    end

    # Tab Creation
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab
        abbr -a :t kitty @ launch --type=tab # Kitty
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab
        abbr -a :t wezterm cli spawn # WezTerm
    end

    # Rename Tab
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Set tab title
        abbr -a :tl "kitty @ set-tab-title" # Kitty -> Usage: :tl "New Title"
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Set tab title
        abbr -a :tl wezterm cli set-tab-title # WezTerm
    end

    # Rename Window
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Set window title
        abbr -a :tw "kitty @ set-window-title" # Kitty
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Set window title
        abbr -a :tw wezterm cli set-window-title # WezTerm
    end

    # Rename Workspace
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Rename workspace (WezTerm only)
        abbr -a :twk wezterm cli rename-workspace # WezTerm
    end
    # Kitty does not have a direct CLI equivalent for renaming a dynamic "workspace" session.

    # Tab Navigation
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Focus previous tab
        abbr -a :tp "kitty @ focus-tab --match neighbor:left" # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Focus next tab
        abbr -a :tn "kitty @ focus-tab --match neighbor:right" # Kitty
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Focus previous tab
        abbr -a :tp wezterm cli activate-tab --tab-relative -1 # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Focus next tab
        abbr -a :tn wezterm cli activate-tab --tab-relative 1 # WezTerm
    end

    # Specialty Tab Shortcuts (New Tab in specific dir)
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/kitty
        abbr -a :tgk kitty @ launch --type=tab --cwd ~/.config/kitty # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/nvim
        abbr -a :tgn kitty @ launch --type=tab --cwd ~/.config/nvim # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/fish
        abbr -a :tgf kitty @ launch --type=tab --cwd ~/.config/fish # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~
        abbr -a :tgh kitty @ launch --type=tab --cwd ~
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.local/share/chezmoi
        abbr -a :tgcz kitty @ launch --type=tab --cwd ~/.local/share/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/chezmoi
        abbr -a :tgcm kitty @ launch --type=tab --cwd ~/.config/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/projects
        abbr -a :tgp kitty @ launch --type=tab --cwd ~/projects # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at / (root)
        abbr -a :tgr kitty @ launch --type=tab -- sudo -i
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/kitty
        abbr -a :tgk wezterm cli spawn --cwd ~/.config/kitty # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/nvim
        abbr -a :tgn wezterm cli spawn --cwd ~/.config/nvim # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/fish
        abbr -a :tgf wezterm cli spawn --cwd ~/.config/fish # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~
        abbr -a :tgh wezterm cli spawn --cwd ~ # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.local/share/chezmoi
        abbr -a :tgcz wezterm cli spawn --cwd ~/.local/share/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/.config/chezmoi
        abbr -a :tgcm wezterm cli spawn --cwd ~/.config/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at ~/projects
        abbr -a :tgp wezterm cli spawn --cwd ~/projects # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New tab at / (root)
        abbr -a :tgr wezterm cli spawn -- sudo -i # WezTerm
    end

    # Specialty Window Shortcuts (New OS Window in specific dir)
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/kitty
        abbr -a :wgk kitty @ launch --type=os-window --cwd ~/.config/kitty # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/nvim
        abbr -a :wgn kitty @ launch --type=os-window --cwd ~/.config/nvim # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/fish
        abbr -a :wgf kitty @ launch --type=os-window --cwd ~/.config/fish # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~
        abbr -a :wgh kitty @ launch --type=os-window --cwd ~
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.local/share/chezmoi
        abbr -a :wgzd kitty @ launch --type=os-window --cwd ~/.local/share/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/chezmoi
        abbr -a :wgcz kitty @ launch --type=os-window --cwd ~/.config/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/projects
        abbr -a :wgp kitty @ launch --type=os-window --cwd ~/projects # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at / (root)
        abbr -a :wgr kitty @ launch --type=os-window -- sudo -i # Kitty
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/kitty
        abbr -a :wgk wezterm cli spawn --new-window --cwd ~/.config/kitty # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/nvim
        abbr -a :wgn wezterm cli spawn --new-window --cwd ~/.config/nvim # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/fish
        abbr -a :wgf wezterm cli spawn --new-window --cwd ~/.config/fish # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~
        abbr -a :wgh wezterm cli spawn --new-window --cwd ~ # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.local/share/chezmoi
        abbr -a :wgzd wezterm cli spawn --new-window --cwd ~/.local/share/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/.config/chezmoi
        abbr -a :wgcz wezterm cli spawn --new-window --cwd ~/.config/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at ~/projects
        abbr -a :wgp wezterm cli spawn --new-window --cwd ~/projects # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc New OS window at / (root)
        abbr -a :wgr wezterm cli spawn --new-window -- sudo -i # WezTerm
    end

    # Specialty Window Vertical Shortcuts (Split Bottom)
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/kitty
        abbr -a :wvgk kitty @ launch --location=hsplit --cwd ~/.config/kitty # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/nvim
        abbr -a :wvgn kitty @ launch --location=hsplit --cwd ~/.config/nvim # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/fish
        abbr -a :wvgf kitty @ launch --location=hsplit --cwd ~/.config/fish # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~
        abbr -a :wvgh kitty @ launch --location=hsplit --cwd ~ # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.local/share/chezmoi
        abbr -a :wvgcz kitty @ launch --location=hsplit --cwd ~/.local/share/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/chezmoi
        abbr -a :wvgcm kitty @ launch --location=hsplit --cwd ~/.config/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/projects
        abbr -a :wvgp kitty @ launch --location=hsplit --cwd ~/projects # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at / (root)
        abbr -a :wvgr kitty @ launch --location=hsplit -- sudo -i # Kitty
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/kitty
        abbr -a :wvgk wezterm cli split-pane --bottom --cwd ~/.config/kitty # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/nvim
        abbr -a :wvgn wezterm cli split-pane --bottom --cwd ~/.config/nvim # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/fish
        abbr -a :wvgf wezterm cli split-pane --bottom --cwd ~/.config/fish # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~
        abbr -a :wvgh wezterm cli split-pane --bottom --cwd ~ # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.local/share/chezmoi
        abbr -a :wvgcz wezterm cli split-pane --bottom --cwd ~/.local/share/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/.config/chezmoi
        abbr -a :wvgcm wezterm cli split-pane --bottom --cwd ~/.config/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at ~/projects
        abbr -a :wvgp wezterm cli split-pane --bottom --cwd ~/projects # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split bottom at / (root)
        abbr -a :wvgr wezterm cli split-pane --bottom -- sudo -i # WezTerm
    end

    # Specialty Window Horizontal Shortcuts (Split Right)
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/kitty
        abbr -a :whgk kitty @ launch --location=vsplit --cwd ~/.config/kitty # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/nvim
        abbr -a :whgn kitty @ launch --location=vsplit --cwd ~/.config/nvim # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/fish
        abbr -a :whgf kitty @ launch --location=vsplit --cwd ~/.config/fish # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~
        abbr -a :whgh kitty @ launch --location=vsplit --cwd ~ # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.local/share/chezmoi
        abbr -a :whgcz kitty @ launch --location=vsplit --cwd ~/.local/share/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/chezmoi
        abbr -a :whgcm kitty @ launch --location=vsplit --cwd ~/.config/chezmoi # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/projects
        abbr -a :whgp kitty @ launch --location=vsplit --cwd ~/projects # Kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at / (root)
        abbr -a :whgr kitty @ launch --location=vsplit --cwd current sudo -i # Kitty -> Specialty cd Shortcuts
        # @category Terminal Windows, Tabs, and Panes
        # @desc cd ~/.config/kitty
        abbr -a :cdk 'cd ~/.config/kitty/ # Kitty Config'
        # @category Terminal Windows, Tabs, and Panes
        # @desc cd ~/.config/kitty; nvim
        abbr -a :cdkn 'cd ~/.config/kitty;nvim'
    end
    if test "$TERM_PROGRAM" = WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/kitty
        abbr -a :whgk wezterm cli split-pane --bottom --cwd ~/.config/kitty # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/nvim
        abbr -a :whgn wezterm cli split-pane --bottom --cwd ~/.config/nvim # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/fish
        abbr -a :whgf wezterm cli split-pane --bottom --cwd ~/.config/fish # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~
        abbr -a :whgh wezterm cli split-pane --bottom --cwd ~ # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.local/share/chezmoi
        abbr -a :whgcz wezterm cli split-pane --bottom --cwd ~/.local/share/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/.config/chezmoi
        abbr -a :whgcm wezterm cli split-pane --bottom --cwd ~/.config/chezmoi # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at ~/projects
        abbr -a :whgp wezterm cli split-pane --bottom --cwd ~/projects # WezTerm
        # @category Terminal Windows, Tabs, and Panes
        # @desc Split right at / (root)
        abbr -a :whgr wezterm cli split-pane --bottom -- sudo -i # WezTerm
    end
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/nvim
    abbr -a :cdn cd '~/.config/nvim/ # Neovim Config'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/nvim; nvim
    abbr -a :cdnn 'cd ~/.config/nvim;nvim'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/fish
    abbr -a :cdf 'cd ~/.config/fish/ # Fish Config'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/fish; nvim
    abbr -a :cdfn 'cd ~/.config/fish;nvim'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~
    abbr -a :cdh 'cd ~ # Home Directory'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~; nvim
    abbr -a :cdhn 'cd ~;nvim'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.local/share/chezmoi
    abbr -a :cdcz cd '~/.local/share/chezmoi/ # Chezmoi Source'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.local/share/chezmoi; nvim
    abbr -a :cdczn 'cd ~/.local/share/chezmoi;nvim'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/chezmoi
    abbr -a :cdcm 'cd ~/.config/chezmoi/ # Chezmoi Config'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/chezmoi; nvim
    abbr -a :cdcmn 'cd ~/.config/chezmoi;nvim'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/projects/...
    abbr -a :cdp --regex ':cdp' --set-cursor 'cd ~/projects/%'
    # abbr -a cdp_slash --position anywhere --regex ':cdp/' --set-cursor 'cd ~/projects/%'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/projects; nvim
    abbr -a :cdpn 'cd ~/projects;nvim'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/wezterm
    abbr -a :cdw 'cd ~/.config/wezterm/ # WezTerm Config'
    # @category Terminal Windows, Tabs, and Panes
    # @desc cd ~/.config/wezterm; nvim
    abbr -a :cdwn 'cd ~/.config/wezterm;nvim'
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc Open new tab with nvim (terminal-aware)
        abbr -a editt kitty @ launch --type tab nvim
    end
    # Spawn window
    if test "$TERM" = xterm-kitty
        # @category Terminal Windows, Tabs, and Panes
        # @desc spwin (spawn new OS window)
        abbr -a :sw spwin
    end
end

### Docker ###
# @category Docker
# @desc docker context use default
abbr -a dcl 'docker context use default # Local Host'
# @category Docker
# @desc ld (lazydocker)
abbr -a lzd ld
# @category Docker
# @desc docker context ls
abbr -a dcls 'docker context ls'

### Beads ###
# @category Miscellaneous
# @desc bd list
abbr -a bl 'bd list'
# @category Miscellaneous
# @desc bd sync
abbr -a bs 'bd sync'
# @category Miscellaneous
# @desc bd create --title
abbr -a bC 'bd create --title'
# @category Miscellaneous
# @desc bd show
abbr -a bsh 'bd show'
# @category Miscellaneous
# @desc lazybeads
abbr -a lb lazybeads

### Systemctl ###
# @category Systemctl
# @desc systemctl
abbr -a sc systemctl
# @category Systemctl
# @desc sudo systemctl
abbr -a ssc 'sudo systemctl'
# @category Systemctl
# @desc systemctl --user
abbr -a scu 'systemctl --user'
# @category Systemctl
# @desc systemctl status
abbr -a st 'systemctl status'
# @category Systemctl
# @desc systemctl start
abbr -a scs 'systemctl start'
# @category Systemctl
# @desc systemctl restart
abbr -a scr 'systemctl restart'
# @category Systemctl
# @desc sudo systemctl status
abbr -a ssct 'sudo systemctl status'
# @category Systemctl
# @desc sudo systemctl start
abbr -a sscs 'sudo systemctl start'
# @category Systemctl
# @desc sudo systemctl restart
abbr -a sscr 'sudo systemctl restart'

### Alternate command names ###
# Expand to the canonical function name so muscle-memory typos still work,
# while surfacing the real command instead of silently forwarding to it.
# @category Miscellaneous
# @desc repo-open
abbr -a open-repo repo-open
# @category Miscellaneous
# @desc open-url
abbr -a url-open open-url

### History Expansions and Substitutions ###
# Bash-style history expansion is opinionated (C3 overrides), gated atomically
# with conf.d/tricks.fish, conf.d/puffer.fish, and functions/expand_*.fish.
if __fish_config_op_enabled (status basename) abbr-overrides
    # @category History Expansion
    # @name !^
    # @desc Expand to the first argument of the previous command
    abbr -a !^ --position anywhere --function expand_bang_caret
    # @category History Expansion
    # @name !*
    # @desc Expand to all arguments of the previous command
    abbr -a '!*' --position anywhere --function expand_bang_all
    # @category History Expansion
    # @name ^old^new^
    # @desc Interactive typo substitution (replace 'old' with 'new' in previous command)
    abbr -a typo_sub --position anywhere --regex '\^([^^]+)\^([^^]*)' --function expand_typo_sub
    # @category History Expansion
    # @name !string
    # @desc Expand to the most recent command starting with 'string'
    abbr -a bang_string --position anywhere --regex '![\w.-]+' --function expand_bang_string
    # @category History Expansion
    # @name !?string?
    # @desc Expand to the most recent command containing 'string'
    abbr -a bang_search --position anywhere --regex '!\?[\w.-]+\??' --function expand_bang_search
    # @category History Expansion
    # @name !-n
    # @desc Expand to the nth-previous command
    abbr -a bang_minus_n --position anywhere --regex '!-(\d+)' --function expand_bang_minus_n
end
