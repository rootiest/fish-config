---
title: Package Management
manTitle: 5.5 Package Management
sidebar:
  order: 5
helpKeywords:
- package-manager
- packages
---

## pkg

    Synopsis:  pkg [-h] [-i|-u] <package> [package...]
    Installs or removes packages using the detected system package manager.
    Supports: paru, yay, pacman, apt, dnf, zypper, yum, brew, pkg.

      (no flag)    Auto mode: installs missing packages, removes installed ones
      -i/--install  Force install
      -u/--uninstall  Force uninstall

    pkg firefox             # auto: install if missing, remove if present
    pkg -i ripgrep fd       # force install
    pkg -u cowsay           # force uninstall

    The package-installed check uses the correct query for each PM:
      pacman/paru/yay  pacman -Qi
      apt              dpkg -s
      dnf/zypper/yum   rpm -q
      brew             brew list
      pkg              pkg info

## search

    Synopsis:  search [args...]
    Interactive AUR package search and install via paru or yay.
    Arch Linux only.

    search neovim

## upgrade

    Synopsis:  upgrade
    Full system upgrade via paru -Syu --noconfirm or yay -Syu --noconfirm.
    Arch Linux only.

## cleanup

    Synopsis:  cleanup
    Lists and removes orphan packages via pacman, logging their names to
    ~/.removed_orphans. Arch Linux only.

## parur

    Synopsis:  parur
    Opens an fzf picker of all installed packages (with pacman -Qi previews),
    then removes the selected packages via paru or yay. Arch Linux only.

    parur

---
