---
title: PATH Setup
manTitle: 2. PATH SETUP
sidebar:
  order: 6
helpKeywords:
- path
---

Directories prepended to PATH in this order (first wins):

| Directory | Purpose |
|---|---|
| `~/.local/bin` | Standard user-local executables |
| `~/Applications` | User-installed standalone apps |
| `~/scripts` | Personal shell scripts |
| `~/bin` | Cargo binaries (appended — lowest priority) |
| `$BUN_INSTALL/bin` | Bun runtime and global packages |
| `$NPM_CONFIG_PREFIX/bin` | Global npm packages |
| `~/.lmstudio/bin` | LM Studio CLI |
| `~/.resend/bin` | Resend CLI |
| `~/.fzf/bin` | `fzf` binary (git-installed) |

Cargo binaries are intentionally appended (lowest priority) to avoid
shadowing system-installed Rust tools.

NOTE: While these directories are merged with your system's existing `$PATH` values, any executables in the prepended directories above will override (shadow) system binaries of the same name.

TIP: This standard PATH setup is gated behind the opinionated component overrides toggle. If you prefer to manage your PATH completely manually, you can disable it by setting `__fish_config_op_overrides` to `0` (or toggle it off in the `config-settings` menu).

---
