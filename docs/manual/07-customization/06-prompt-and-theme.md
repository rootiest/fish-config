---
title: Prompt and Theme
---

### Starship

The primary prompt is Starship, initialized by conf.d/starship.fish.
Configure it via ~/.config/starship.toml.

conf.d/starship.fish defines a fish_prompt wrapper that only activates when
starship is in PATH. It emits OSC 133;A (prompt start) immediately before
Starship renders and OSC 133;B (input start) immediately after, placing both
markers on the prompt line itself. This allows ov to use them as sticky
section headers when browsing scrollback logs. Without Starship, fish's
built-in prompt handles these markers automatically.

### Catppuccin Fallback Prompt

When Starship is absent or C3 overrides are disabled, a built-in nim-style
two-line prompt activates from functions/fish_prompt.fish. No external
dependencies — fish builtins only.

Layout:

    ┬─[user@host:~/path] (main)
    ╰─>$

Elements:

    user        Yellow (Catppuccin Yellow); red if root
    @host       Blue (local) or Teal (SSH)
    ~/path      prompt_pwd abbreviation (Catppuccin Text)
    (main)      Current git branch in Catppuccin Pink; omitted outside repos
    ─[V:name]   Active Python venv basename; omitted when none
    ─[N/I/R/V]  Vi-mode indicator when vi bindings are active
    ┬─ / ╰─>    Connector lines: Catppuccin Green on success, Red on failure

The right prompt (fish_right_prompt.fish) always renders, regardless of C3
state. On failure it shows a red ✘ and the exit code; on success it shows
only the dim timestamp. When starship is installed and C3 is enabled, the
active Docker context is also shown (if non-default):

    ✘ 1   󰡨 myctx   Fri Jun 12 00:51:21 2026     ← failed, starship+C3 active
    ✘ 1   Fri Jun 12 00:51:21 2026               ← failed, fallback prompt
    Fri Jun 12 00:51:21 2026                     ← success (no ✘)

### FZF

FZF is themed to Catppuccin Mocha via FZF_DEFAULT_OPTS set in
integrations/fzf.fish. The colors applied:

    Background:   #1E1E2E (base)    #313244 (surface0)
    Foreground:   #CDD6F4 (text)
    Highlights:   #F38BA8 (red)     #CBA6F7 (mauve)    #B4BEFE (lavender)

To customize, override FZF_DEFAULT_OPTS in local.fish.

### Catppuccin Mocha Syntax Highlighting

The Catppuccin Mocha theme ships with this config in themes/ and is applied
on first run via `conf.d/first_run.fish`. Colors are stored in fish_variables
(universal). To switch variants, install a different theme from themes/:

    fish_config theme save "Catppuccin Latte"

---
