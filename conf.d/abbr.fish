# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

### Abreviations ###

# Neovim
abbr -a n nvim
abbr -a nv nvim
abbr -a neovim nvim
abbr -a cdnv 'cd ~/.config/nvim # Neovim Config'
abbr -a cdnvn 'cd ~/.config/nvim;nvim'
# VSCode
abbr -a v antigravity
# Kate
abbr -a k kate
# WezTerm SSH
abbr -a s wezterm ssh
# Neovim in a new tab
#abbr -a editt wezterm cli spawn nvim # WezTerm
abbr -a editt kitty @ launch --type=tab --cwd=current nvim # Kitty
# LazyGit
abbr -a lg lazygit
# Sudo shell
abbr -a sudu sudo -s
# Kitty
abbr -a kt kitty
# cat
abbr -a c cat
# chezmoi
abbr -a cm chezmoi
# chezmoi cd
abbr -a cmcd chezmoi cd
abbr -a czcd chezmoi cd
abbr -a cdcm chezmoi cd
abbr -a cdcz chezmoi cd
# chezmoi edit
abbr -a cme chezmoi edit
abbr -a cze chezmoi edit
# chezmoi add
abbr -a cmad chezmoi add
abbr -a czad chezmoi add
# chezmoi apply
abbr -a cmap chezmoi apply
abbr -a czap chezmoi apply
# chezmoi rm
abbr -a cmrm chezmoi forget
abbr -a cmf chezmoi forget
abbr -a czrm chezmoi forget
abbr -a czf chezmoi forget
# chezmoi init
abbr -a cmi chezmoi init
abbr -a czi chezmoi init
# Edit
abbr -a e edit
# Sudoedit
abbr -a se sudoedit
# Git
abbr -a g git
# Antigravity
abbr -a ag antigravity
abbr -a ag. antigravity .
# Quit
# abbr -a :q wezterm cli kill-pane # WezTerm
# abbr -a :Q wezterm cli kill-pane # WezTerm
abbr -a :q kitty @ close-window # Kitty (Closes the active split/pane)
abbr -a :Q kitty @ close-tab # Kitty (Closes the whole tab)

######### Alternates ##########
### ls alternates
# List all files
abbr -a l ls
# List all files by size
abbr -a lS lss
# List all files by reverse modified time
abbr -a lsR lsr
# List by extension
abbr -a lX lx
# Tree listing (depth 2)
abbr -a lT lt
# Full tree listing
abbr -a lsT lstree

# Window Creation (OS Windows)
# abbr -a :w wezterm cli spawn --new-window # WezTerm
abbr -a :w kitty @ launch --type=os-window # Kitty

# Window Splits (Panes)
# abbr -a :wv wezterm cli split-pane --bottom # WezTerm
abbr -a :wv kitty @ launch --location=hsplit # Kitty (Horizontal split)
# abbr -a :wh wezterm cli split-pane --right # WezTerm
abbr -a :wh kitty @ launch --location=vsplit # Kitty (Vertical split)

# Window Detach (Move Pane)
# abbr -a :wo wezterm cli move-pane-to-new-tab --new-window # WezTerm
abbr -a :wo kitty @ detach-window --target-tab=new # Kitty (Moves pane to new tab)
# abbr -a :wot wezterm cli move-pane-to-new-tab # WezTerm
abbr -a :wot kitty @ detach-window # Kitty (Same as above, default behavior)

# Tab Creation
# abbr -a :t wezterm cli spawn # WezTerm
abbr -a :t kitty @ launch --type=tab # Kitty

# Rename Tab
# abbr -a :tl wezterm cli set-tab-title # WezTerm
abbr -a :tl "kitty @ set-tab-title" # Kitty -> Usage: :tl "New Title"

# Rename Window
# abbr -a :tw wezterm cli set-window-title # WezTerm
abbr -a :tw "kitty @ set-window-title" # Kitty

# Rename Workspace
# abbr -a :twk wezterm cli rename-workspace # WezTerm
# Kitty does not have a direct CLI equivalent for renaming a dynamic "workspace" session.

# Tab Navigation
# abbr -a :tp wezterm cli activate-tab --tab-relative -1 # WezTerm
abbr -a :tp "kitty @ focus-tab --match neighbor:left" # Kitty
# abbr -a :tn wezterm cli activate-tab --tab-relative 1 # WezTerm
abbr -a :tn "kitty @ focus-tab --match neighbor:right" # Kitty

# Specialty Tab Shortcuts (New Tab in specific dir)
# abbr -a :tgk wezterm cli spawn --cwd ~/.config/kitty # WezTerm
abbr -a :tgk kitty @ launch --type=tab --cwd ~/.config/kitty # Kitty
# abbr -a :tgn wezterm cli spawn --cwd ~/.config/nvim # WezTerm
abbr -a :tgn kitty @ launch --type=tab --cwd ~/.config/nvim # Kitty
# abbr -a :tgf wezterm cli spawn --cwd ~/.config/fish # WezTerm
abbr -a :tgf kitty @ launch --type=tab --cwd ~/.config/fish # Kitty
# abbr -a :tgh wezterm cli spawn --cwd ~ # WezTerm
abbr -a :tgh kitty @ launch --type=tab --cwd ~
# abbr -a :tgcz wezterm cli spawn --cwd ~/.local/share/chezmoi # WezTerm
abbr -a :tgcz kitty @ launch --type=tab --cwd ~/.local/share/chezmoi # Kitty
# abbr -a :tgcm wezterm cli spawn --cwd ~/.config/chezmoi # WezTerm
abbr -a :tgcm kitty @ launch --type=tab --cwd ~/.config/chezmoi # Kitty
# abbr -a :tgp wezterm cli spawn --cwd ~/projects # WezTerm
abbr -a :tgp kitty @ launch --type=tab --cwd ~/projects # Kitty
# abbr -a :tgr wezterm cli spawn -- sudo -i # WezTerm
abbr -a :tgr kitty @ launch --type=tab -- sudo -i

# Specialty Window Shortcuts (New OS Window in specific dir)
# abbr -a :wgk wezterm cli spawn --new-window --cwd ~/.config/kitty # WezTerm
abbr -a :wgk kitty @ launch --type=os-window --cwd ~/.config/kitty # Kitty
# abbr -a :wgn wezterm cli spawn --new-window --cwd ~/.config/nvim # WezTerm
abbr -a :wgn kitty @ launch --type=os-window --cwd ~/.config/nvim # Kitty
# abbr -a :wgf wezterm cli spawn --new-window --cwd ~/.config/fish # WezTerm
abbr -a :wgf kitty @ launch --type=os-window --cwd ~/.config/fish # Kitty
# abbr -a :wgh wezterm cli spawn --new-window --cwd ~ # WezTerm
abbr -a :wgh kitty @ launch --type=os-window --cwd ~
# abbr -a :wgzd wezterm cli spawn --new-window --cwd ~/.local/share/chezmoi # WezTerm
abbr -a :wgzd kitty @ launch --type=os-window --cwd ~/.local/share/chezmoi # Kitty
# abbr -a :wgcz wezterm cli spawn --new-window --cwd ~/.config/chezmoi # WezTerm
abbr -a :wgcz kitty @ launch --type=os-window --cwd ~/.config/chezmoi # Kitty
# abbr -a :wgp wezterm cli spawn --new-window --cwd ~/projects # WezTerm
abbr -a :wgp kitty @ launch --type=os-window --cwd ~/projects # Kitty
# abbr -a :wgr wezterm cli spawn --new-window -- sudo -i # WezTerm
abbr -a :wgr kitty @ launch --type=os-window -- sudo -i # Kitty

# Specialty Window Vertical Shortcuts (Split Bottom)
# abbr -a :wvgk wezterm cli split-pane --bottom --cwd ~/.config/kitty # WezTerm
abbr -a :wvgk kitty @ launch --location=hsplit --cwd ~/.config/kitty # Kitty
# abbr -a :wvgn wezterm cli split-pane --bottom --cwd ~/.config/nvim # WezTerm
abbr -a :wvgn kitty @ launch --location=hsplit --cwd ~/.config/nvim # Kitty
# abbr -a :wvgf wezterm cli split-pane --bottom --cwd ~/.config/fish # WezTerm
abbr -a :wvgf kitty @ launch --location=hsplit --cwd ~/.config/fish # Kitty
# abbr -a :wvgh wezterm cli split-pane --bottom --cwd ~ # WezTerm
abbr -a :wvgh kitty @ launch --location=hsplit --cwd ~ # Kitty
# abbr -a :wvgcz wezterm cli split-pane --bottom --cwd ~/.local/share/chezmoi # WezTerm
abbr -a :wvgcz kitty @ launch --location=hsplit --cwd ~/.local/share/chezmoi # Kitty
# abbr -a :wvgcm wezterm cli split-pane --bottom --cwd ~/.config/chezmoi # WezTerm
abbr -a :wvgcm kitty @ launch --location=hsplit --cwd ~/.config/chezmoi # Kitty
# abbr -a :wvgp wezterm cli split-pane --bottom --cwd ~/projects # WezTerm
abbr -a :wvgp kitty @ launch --location=hsplit --cwd ~/projects # Kitty
# abbr -a :wvgr wezterm cli split-pane --bottom -- sudo -i # WezTerm
abbr -a :wvgr kitty @ launch --location=hsplit -- sudo -i # Kitty

# Specialty Window Horizontal Shortcuts (Split Right)
# abbr -a :whgk wezterm cli split-pane --bottom --cwd ~/.config/kitty # WezTerm
abbr -a :whgk kitty @ launch --location=vsplit --cwd ~/.config/kitty # Kitty
# abbr -a :whgn wezterm cli split-pane --bottom --cwd ~/.config/nvim # WezTerm
abbr -a :whgn kitty @ launch --location=vsplit --cwd ~/.config/nvim # Kitty
# abbr -a :whgf wezterm cli split-pane --bottom --cwd ~/.config/fish # WezTerm
abbr -a :whgf kitty @ launch --location=vsplit --cwd ~/.config/fish # Kitty
# abbr -a :whgh wezterm cli split-pane --bottom --cwd ~ # WezTerm
abbr -a :whgh kitty @ launch --location=vsplit --cwd ~ # Kitty
# abbr -a :whgcz wezterm cli split-pane --bottom --cwd ~/.local/share/chezmoi # WezTerm
abbr -a :whgcz kitty @ launch --location=vsplit --cwd ~/.local/share/chezmoi # Kitty
# abbr -a :whgcm wezterm cli split-pane --bottom --cwd ~/.config/chezmoi # WezTerm
abbr -a :whgcm kitty @ launch --location=vsplit --cwd ~/.config/chezmoi # Kitty
# abbr -a :whgp wezterm cli split-pane --bottom --cwd ~/projects # WezTerm
abbr -a :whgp kitty @ launch --location=vsplit --cwd ~/projects # Kitty
# abbr -a :whgr wezterm cli split-pane --bottom -- sudo -i # WezTerm
abbr -a :whgr kitty @ launch --location=vsplit --cwd current sudo -i # Kitty -> Specialty cd Shortcuts
abbr -a :cdk 'cd ~/.config/kitty/ # Kitty Config'
abbr -a :cdkn 'cd ~/.config/kitty;nvim'
abbr -a :cdn cd '~/.config/nvim/ # Neovim Config'
abbr -a :cdnn 'cd ~/.config/nvim;nvim'
abbr -a :cdf 'cd ~/.config/fish/ # Fish Config'
abbr -a :cdfn 'cd ~/.config/fish;nvim'
abbr -a :cdh 'cd ~ # Home Directory'
abbr -a :cdhn 'cd ~;nvim'
abbr -a :cdcz cd '~/.local/share/chezmoi/ # Chezmoi Source'
abbr -a :cdczn 'cd ~/.local/share/chezmoi;nvim'
abbr -a :cdcm 'cd ~/.config/chezmoi/ # Chezmoi Config'
abbr -a :cdcmn 'cd ~/.config/chezmoi;nvim'
abbr -a :cdp --regex ':cdp' --set-cursor 'cd ~/projects/%'
# abbr -a cdp_slash --position anywhere --regex ':cdp/' --set-cursor 'cd ~/projects/%'
abbr -a :cdpn 'cd ~/projects;nvim'
abbr -a :cdw 'cd ~/.config/wezterm/ # WezTerm Config'
abbr -a :cdwn 'cd ~/.config/wezterm;nvim'
abbr -a editt kitty @ launch --type tab nvim
# Spawn window
abbr -a :sw spwin

### Docker ###
abbr -a dcl 'docker context use default # Local Host'
abbr -a lzd ld
abbr -a dcls 'docker context ls'

### Beads ###
abbr -a bl 'bd list'
abbr -a bs 'bd sync'
abbr -a bC 'bd create --title'
abbr -a bsh 'bd show'
abbr -a lb lazybeads

### Systemctl ###
abbr -a sc systemctl
abbr -a ssc 'sudo systemctl'
abbr -a scu 'systemctl --user'
abbr -a st 'systemctl status'
abbr -a scs 'systemctl start'
abbr -a scr 'systemctl restart'
abbr -a ssct 'sudo systemctl status'
abbr -a sscs 'sudo systemctl start'
abbr -a sscr 'sudo systemctl restart'
