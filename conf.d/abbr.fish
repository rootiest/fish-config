# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
#          ╭──────────────────────────────────────────────────────────╮
#          │                       Abreviations                       │
#          ╰──────────────────────────────────────────────────────────╯
#
# This file contains all the abbreviations for the terminal.
# It is sourced by Fish on startup.

# Neovim
abbr -a n nvim
abbr -a nv nvim
abbr -a neovim nvim
abbr -a cdnv 'cd ~/.config/nvim # Neovim Config'
abbr -a cdnvn 'cd ~/.config/nvim;nvim'
# VSCode
abbr -a v antigravity-ide
# Kate
abbr -a k kate
# WezTerm SSH
if test "$TERM_PROGRAM" = WezTerm
    abbr -a s wezterm ssh
end
# Neovim in a new tab
if test "$TERM" = xterm-kitty
    abbr -a editt kitty @ launch --type=tab --cwd=current nvim # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a editt wezterm cli spawn nvim # WezTerm
end
# LazyGit
abbr -a lg lazygit
# Sudo shell
abbr -a sudu sudo -s
# Kitty
if test "$TERM" = xterm-kitty
    abbr -a kt kitty
end
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
abbr -a gitig gi
abbr -a git-ignore gi
# Antigravity
abbr -a ag antigravity
abbr -a ag. antigravity .
# Quit
abbr -a /exit exit
if test "$TERM" = xterm-kitty
    abbr -a :q kitty @ close-window # Kitty (Closes the active split/pane)
    abbr -a :Q kitty @ close-tab # Kitty (Closes the whole tab)
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :q wezterm cli kill-pane # WezTerm
    abbr -a :Q wezterm cli kill-pane # WezTerm
end

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
### speed-test alternates
# Speedtest using fast.com
abbr -a speedtest-fast fast-cli

# Window Creation (OS Windows)
if test "$TERM" = xterm-kitty
    abbr -a :w kitty @ launch --type=os-window # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :w wezterm cli spawn --new-window # WezTerm
end

# Window Splits (Panes)
if test "$TERM" = xterm-kitty
    abbr -a :wv kitty @ launch --location=hsplit # Kitty (Horizontal split)
    abbr -a :wh kitty @ launch --location=vsplit # Kitty (Vertical split)
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :wv wezterm cli split-pane --bottom # WezTerm
    abbr -a :wh wezterm cli split-pane --right # WezTerm
end

# Window Detach (Move Pane)
if test "$TERM" = xterm-kitty
    abbr -a :wo kitty @ detach-window --target-tab=new # Kitty (Moves pane to new tab)
    abbr -a :wot kitty @ detach-window # Kitty (Same as above, default behavior)
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :wo wezterm cli move-pane-to-new-tab --new-window # WezTerm
    abbr -a :wot wezterm cli move-pane-to-new-tab # WezTerm
end

# Tab Creation
if test "$TERM" = xterm-kitty
    abbr -a :t kitty @ launch --type=tab # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :t wezterm cli spawn # WezTerm
end

# Rename Tab
if test "$TERM" = xterm-kitty
    abbr -a :tl "kitty @ set-tab-title" # Kitty -> Usage: :tl "New Title"
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :tl wezterm cli set-tab-title # WezTerm
end

# Rename Window
if test "$TERM" = xterm-kitty
    abbr -a :tw "kitty @ set-window-title" # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :tw wezterm cli set-window-title # WezTerm
end

# Rename Workspace
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :twk wezterm cli rename-workspace # WezTerm
end
# Kitty does not have a direct CLI equivalent for renaming a dynamic "workspace" session.

# Tab Navigation
if test "$TERM" = xterm-kitty
    abbr -a :tp "kitty @ focus-tab --match neighbor:left" # Kitty
    abbr -a :tn "kitty @ focus-tab --match neighbor:right" # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :tp wezterm cli activate-tab --tab-relative -1 # WezTerm
    abbr -a :tn wezterm cli activate-tab --tab-relative 1 # WezTerm
end

# Specialty Tab Shortcuts (New Tab in specific dir)
if test "$TERM" = xterm-kitty
    abbr -a :tgk kitty @ launch --type=tab --cwd ~/.config/kitty # Kitty
    abbr -a :tgn kitty @ launch --type=tab --cwd ~/.config/nvim # Kitty
    abbr -a :tgf kitty @ launch --type=tab --cwd ~/.config/fish # Kitty
    abbr -a :tgh kitty @ launch --type=tab --cwd ~
    abbr -a :tgcz kitty @ launch --type=tab --cwd ~/.local/share/chezmoi # Kitty
    abbr -a :tgcm kitty @ launch --type=tab --cwd ~/.config/chezmoi # Kitty
    abbr -a :tgp kitty @ launch --type=tab --cwd ~/projects # Kitty
    abbr -a :tgr kitty @ launch --type=tab -- sudo -i
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :tgk wezterm cli spawn --cwd ~/.config/kitty # WezTerm
    abbr -a :tgn wezterm cli spawn --cwd ~/.config/nvim # WezTerm
    abbr -a :tgf wezterm cli spawn --cwd ~/.config/fish # WezTerm
    abbr -a :tgh wezterm cli spawn --cwd ~ # WezTerm
    abbr -a :tgcz wezterm cli spawn --cwd ~/.local/share/chezmoi # WezTerm
    abbr -a :tgcm wezterm cli spawn --cwd ~/.config/chezmoi # WezTerm
    abbr -a :tgp wezterm cli spawn --cwd ~/projects # WezTerm
    abbr -a :tgr wezterm cli spawn -- sudo -i # WezTerm
end

# Specialty Window Shortcuts (New OS Window in specific dir)
if test "$TERM" = xterm-kitty
    abbr -a :wgk kitty @ launch --type=os-window --cwd ~/.config/kitty # Kitty
    abbr -a :wgn kitty @ launch --type=os-window --cwd ~/.config/nvim # Kitty
    abbr -a :wgf kitty @ launch --type=os-window --cwd ~/.config/fish # Kitty
    abbr -a :wgh kitty @ launch --type=os-window --cwd ~
    abbr -a :wgzd kitty @ launch --type=os-window --cwd ~/.local/share/chezmoi # Kitty
    abbr -a :wgcz kitty @ launch --type=os-window --cwd ~/.config/chezmoi # Kitty
    abbr -a :wgp kitty @ launch --type=os-window --cwd ~/projects # Kitty
    abbr -a :wgr kitty @ launch --type=os-window -- sudo -i # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :wgk wezterm cli spawn --new-window --cwd ~/.config/kitty # WezTerm
    abbr -a :wgn wezterm cli spawn --new-window --cwd ~/.config/nvim # WezTerm
    abbr -a :wgf wezterm cli spawn --new-window --cwd ~/.config/fish # WezTerm
    abbr -a :wgh wezterm cli spawn --new-window --cwd ~ # WezTerm
    abbr -a :wgzd wezterm cli spawn --new-window --cwd ~/.local/share/chezmoi # WezTerm
    abbr -a :wgcz wezterm cli spawn --new-window --cwd ~/.config/chezmoi # WezTerm
    abbr -a :wgp wezterm cli spawn --new-window --cwd ~/projects # WezTerm
    abbr -a :wgr wezterm cli spawn --new-window -- sudo -i # WezTerm
end

# Specialty Window Vertical Shortcuts (Split Bottom)
if test "$TERM" = xterm-kitty
    abbr -a :wvgk kitty @ launch --location=hsplit --cwd ~/.config/kitty # Kitty
    abbr -a :wvgn kitty @ launch --location=hsplit --cwd ~/.config/nvim # Kitty
    abbr -a :wvgf kitty @ launch --location=hsplit --cwd ~/.config/fish # Kitty
    abbr -a :wvgh kitty @ launch --location=hsplit --cwd ~ # Kitty
    abbr -a :wvgcz kitty @ launch --location=hsplit --cwd ~/.local/share/chezmoi # Kitty
    abbr -a :wvgcm kitty @ launch --location=hsplit --cwd ~/.config/chezmoi # Kitty
    abbr -a :wvgp kitty @ launch --location=hsplit --cwd ~/projects # Kitty
    abbr -a :wvgr kitty @ launch --location=hsplit -- sudo -i # Kitty
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :wvgk wezterm cli split-pane --bottom --cwd ~/.config/kitty # WezTerm
    abbr -a :wvgn wezterm cli split-pane --bottom --cwd ~/.config/nvim # WezTerm
    abbr -a :wvgf wezterm cli split-pane --bottom --cwd ~/.config/fish # WezTerm
    abbr -a :wvgh wezterm cli split-pane --bottom --cwd ~ # WezTerm
    abbr -a :wvgcz wezterm cli split-pane --bottom --cwd ~/.local/share/chezmoi # WezTerm
    abbr -a :wvgcm wezterm cli split-pane --bottom --cwd ~/.config/chezmoi # WezTerm
    abbr -a :wvgp wezterm cli split-pane --bottom --cwd ~/projects # WezTerm
    abbr -a :wvgr wezterm cli split-pane --bottom -- sudo -i # WezTerm
end

# Specialty Window Horizontal Shortcuts (Split Right)
if test "$TERM" = xterm-kitty
    abbr -a :whgk kitty @ launch --location=vsplit --cwd ~/.config/kitty # Kitty
    abbr -a :whgn kitty @ launch --location=vsplit --cwd ~/.config/nvim # Kitty
    abbr -a :whgf kitty @ launch --location=vsplit --cwd ~/.config/fish # Kitty
    abbr -a :whgh kitty @ launch --location=vsplit --cwd ~ # Kitty
    abbr -a :whgcz kitty @ launch --location=vsplit --cwd ~/.local/share/chezmoi # Kitty
    abbr -a :whgcm kitty @ launch --location=vsplit --cwd ~/.config/chezmoi # Kitty
    abbr -a :whgp kitty @ launch --location=vsplit --cwd ~/projects # Kitty
    abbr -a :whgr kitty @ launch --location=vsplit --cwd current sudo -i # Kitty -> Specialty cd Shortcuts
    abbr -a :cdk 'cd ~/.config/kitty/ # Kitty Config'
    abbr -a :cdkn 'cd ~/.config/kitty;nvim'
end
if test "$TERM_PROGRAM" = WezTerm
    abbr -a :whgk wezterm cli split-pane --bottom --cwd ~/.config/kitty # WezTerm
    abbr -a :whgn wezterm cli split-pane --bottom --cwd ~/.config/nvim # WezTerm
    abbr -a :whgf wezterm cli split-pane --bottom --cwd ~/.config/fish # WezTerm
    abbr -a :whgh wezterm cli split-pane --bottom --cwd ~ # WezTerm
    abbr -a :whgcz wezterm cli split-pane --bottom --cwd ~/.local/share/chezmoi # WezTerm
    abbr -a :whgcm wezterm cli split-pane --bottom --cwd ~/.config/chezmoi # WezTerm
    abbr -a :whgp wezterm cli split-pane --bottom --cwd ~/projects # WezTerm
    abbr -a :whgr wezterm cli split-pane --bottom -- sudo -i # WezTerm
end
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
if test "$TERM" = xterm-kitty
    abbr -a editt kitty @ launch --type tab nvim
end
# Spawn window
if test "$TERM" = xterm-kitty
    abbr -a :sw spwin
end

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

### History Expansions and Substitutions ###
abbr -a !^ --position anywhere --function expand_bang_caret
abbr -a '!*' --position anywhere --function expand_bang_all
abbr -a typo_sub --position anywhere --regex '\^([^^]+)\^([^^]*)' --function expand_typo_sub
abbr -a bang_string --position anywhere --regex '![\w.-]+' --function expand_bang_string
abbr -a bang_search --position anywhere --regex '!\?[\w.-]+\??' --function expand_bang_search
abbr -a bang_minus_n --position anywhere --regex '!-(\d+)' --function expand_bang_minus_n
