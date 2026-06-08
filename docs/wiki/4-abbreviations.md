# 4. ABBREVIATIONS

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | **4. Abbreviations** | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Viewing This Manual](9-viewing-this-manual.md) | [10. Installation](10-installation.md) | [11. Personalization](11-personalization.md)

---

Abbreviations expand when you press Space or Enter. They are terminal-aware:
some expand differently in Kitty vs WezTerm vs other terminals.

## 4.1 Editors

    n / nv / neovim    nvim
    e                  edit
    se                 sudoedit
    k                  kate
    editt              Open new tab with nvim (terminal-aware)
    cdnv               cd ~/.config/nvim
    cdnvn              cd ~/.config/nvim; nvim

## 4.2 Navigation and Listing

    l                  ls
    lS                 lss       (sort by size)
    lsR                lsr       (sort by time, oldest first)
    lX                 lx        (sort by extension)
    lT                 lt        (tree, depth 2)
    lsT                lstree    (full recursive tree)
    lzd                ld        (lazydocker)
    cdi                zi        (interactive zoxide picker)

## 4.3 Git

    g                  git
    lg                 lazygit
    gitig / git-ignore gi        (generate .gitignore)

## 4.4 Terminal Windows, Tabs, and Panes

These abbreviations control the terminal emulator. Each has a Kitty
variant and a WezTerm variant; the correct one is inserted based on
$TERM or $TERM_PROGRAM.

    :w          New OS window
    :wv         Split pane horizontally (new pane below)
    :wh         Split pane vertically (new pane to the right)
    :wo         Detach current window to its own OS window
    :wot        Move current pane to a new tab
    :t          New tab
    :tl         Set tab title
    :tw         Set window title
    :twk        Rename workspace (WezTerm only)
    :tp         Focus previous tab
    :tn         Focus next tab
    :q          Close current pane/window
    :Q          Close current tab
    :sw         spwin (spawn new OS window)

Quick-navigate shortcuts open windows/tabs/panes with preset working dirs:

    :tgk    New tab at ~/.config/kitty
    :tgn    New tab at ~/.config/nvim
    :tgf    New tab at ~/.config/fish
    :tgh    New tab at ~
    :tgcz   New tab at chezmoi source dir
    :tgcm   New tab at chezmoi source dir
    :tgp    New tab at ~/projects
    :tgr    New tab at / (root)

Prefixes :wg* and :wvg* / :whg* open OS windows or splits to the same
set of dirs, respectively.

Prefixes :cd* open tabs with a quick cd shortcut:

    :cdn    cd ~/.config/nvim
    :cdf    cd ~/.config/fish
    :cdh    cd ~
    :cdcz   cd to chezmoi source
    :cdp    cd ~/projects

Appending n to any :cd* abbreviation also runs nvim after changing dir.

## 4.5 Chezmoi

    cm / cme / cmi / cmap / cmad / cmrm / cmcd /
    cz / cze / czi / czap / czad / czrm / czcd

    cm / cz          chezmoi
    cmcd / czcd      chezmoi cd
    cme / cze        chezmoi edit
    cmad / czad      chezmoi add
    cmap / czap      chezmoi apply
    cmrm / cmf / czrm / czf    chezmoi forget
    cmi / czi        chezmoi init

## 4.6 Docker

    dcl         docker context use default
    dcls        docker context ls
    lzd         ld (lazydocker)

## 4.7 Systemctl

    sc          systemctl
    ssc         sudo systemctl
    scu         systemctl --user
    st          systemctl status
    scs         sudo systemctl start
    scr         sudo systemctl restart
    ssct        sudo systemctl start
    sscs        sudo systemctl stop
    sscr        sudo systemctl restart

## 4.8 AI Assistants

    ag          antigravity
    ag.         antigravity .
    v           antigravity-ide
    s           wezterm ssh (WezTerm only)

## 4.9 History Expansion

These are implemented as keybinding helpers, but can also be typed:

    !^          Expand to first argument of previous command
    !*          Expand to all arguments of previous command
    typo_sub    Interactive typo substitution (Ctrl+F)
    bang_string !string expansion
    bang_search !?string search
    bang_minus_n  !-n  (nth-previous command)

## 4.10 Miscellaneous

    /exit       exit
    :q          Close pane (alias for terminal close)
    :Q          Close tab
    sudu        sudo -s
    kt          kitty (Kitty only)
    c           cat
    speedtest-fast  fast-cli
    bl          bd list
    bs          bd sync
    bC          bd create --title
    bsh         bd show
    lb          lazybeads

## 4.11 Shell Aliases

These aliases are defined in conf.d/tricks.fish via alias (which creates Fish
functions). They are active in all interactive sessions.

### Navigation

    ..      cd ..
    ...     cd ../..
    ....    cd ../../..
    .....   cd ../../../..
    ......  cd ../../../../..

### Color Overrides

Force color output for common tools:

    grep    grep --color=auto
    fgrep   fgrep --color=auto
    egrep   egrep --color=auto
    dir     dir --color=auto
    vdir    vdir --color=auto

### Safety Wrappers

Add -i (interactive confirmation) to destructive commands:

    cp      cp -i
    mv      mv -i

### Archives and Networking

    tarnow  tar -acf              Create compressed archive (auto-detects format)
    untar   tar -zxvf             Extract a gzip-compressed archive
    wget    wget -c               Resume interrupted downloads by default
    tb      nc termbin.com 9999   Pipe content to termbin.com for quick sharing

### System Logs

    jctl    journalctl -p 3 -xb   Show priority-3 (error) journal entries
                                    from the current boot

---
