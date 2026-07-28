---
title: Customization
manTitle: 7. CUSTOMIZATION
sidebar:
  order: 11
helpKeywords:
- customization
- customize
---
This section explains how to adapt the configuration to your specific workflow, including local machine overrides and opinionated component toggles.

## Machine-local Configuration

Place machine-specific settings that should not be committed to git in:

    $__fish_user_dots_path/local.fish

`__fish_user_dots_path` defaults to `~/.config/.user-dots/fish`. Set a
custom location with:

    set -U __fish_user_dots_path /path/to/your/dots/fish

Typical uses: additional PATH entries, local aliases, hostname-specific env
vars, work-specific tool configs.

For convenience, a git-ignored `user-dots` symlink in the fish config
directory tracks `$__fish_user_dots_path` so the overlay can be browsed from
`~/.config/fish/`. It is created if missing and repointed if the path changes.
Opt out by setting `__fish_user_dots_symlink` to a falsy value, or toggling
"Dots link" off on the config-settings Paths page — this stops generation and
removes any existing link. It only ever manages a symlink and never clobbers a
real file or directory at that path.

## Secrets and API Keys

    $__fish_user_dots_path/secrets.fish

Store API tokens, GPG keys, private credentials here. This file is never
committed. It is sourced by local.fish directly, not by config.fish.

`local.fish` is sourced at the end of config.fish on every interactive
session, so it and its companion secrets.fish can override anything set
earlier.

## Overriding Configuration Variables

Any variable set in local.fish after the main config loads takes effect.
Example: to increase the scrollback history limit:

    # in local.fish
    set -gx SCROLLBACK_HISTORY_MAX_FILES 200

## Fish Universal Variables

Some settings (fzf colors, theme) are stored in fish_variables via
`set -U`. These are machine-local and git-ignored. Do not commit
fish_variables.

## Opinionated Components (Minimal Mode)

Every opinionated piece of this config is active by default but can be
switched off through six category opt-out variables, each evaluated via
__fish_variable_check. Set a variable to any falsy value (0, false, no,
off, n) to disable its category; erase it or set a truthy value (1, true,
yes, on, y) to re-enable. Unset means enabled — except for C5 logging, which
is opt-in (see below).

An explicit per-category truthy value takes precedence over the master
switch: setting __fish_config_opinionated=0 disables all unset categories,
but a category with an explicit truthy value remains enabled regardless.

C5 (logging) is the one exception to "unset means enabled". Because it
writes terminal output to disk, it is opt-in: unset means disabled, and the
master switch cannot enable it. Only an explicit truthy value turns logging
on.

    Variable                        Disables
    ────────────────────────────────────────
    __fish_config_op_aliases        Command shadows and flag injection:
                                    ls->eza, cat->bat, cd->zoxide,
                                    rm->trash, less->ov, top->btop,
                                    ping->prettyping, ssh->kitten,
                                    du->duf/dust, mkdir/bash wrappers,
                                    history timestamps, grep/cp/mv/wget
                                    flag injection, help intercept, claude
                                    AGENTS.md auto-link
    __fish_config_op_autoexec       Startup side-effects: Fisher
                                    bootstrap, theme apply, paru/yay
                                    wrapper generation, auto venv
                                    activation, WakaTime hook
    __fish_config_op_overrides      Key and env overrides: Vi mode,
                                    exit->smart_exit, PAGER/MANPAGER,
                                    CDPATH, bang-bang system, autopair,
                                    puffer, starship prompt, theme
                                    colors, FZF_DEFAULT_OPTS, right
                                    prompt
    __fish_config_op_integrations   Terminal/tool coupling: Kitty/
                                    WezTerm window abbreviations, done
                                    notifications, spwin/tab/split,
                                    hist, logs, upgrade, WakaTime
    __fish_config_op_logging        Logging & capture (OPT-IN — this one
                                    is off unless explicitly enabled):
                                    scrollback capture on exit, paru/yay
                                    AUR log wrappers, Kitty watcher
                                    capture; sentinel file coordinates
                                    cross-process state
    __fish_config_op_greeting       Greeting & first-run UI: per-session
                                    fish_greeting override (defines empty
                                    function late in config.fish to
                                    suppress distro greetings such as
                                    CachyOS fastfetch); first-run welcome
                                    banner in conf.d/first_run.fish

Examples:

    # Disable command shadows only (rm becomes plain rm again):
    set -U __fish_config_op_aliases off

    # Turn session logging on (opt-in; off until you do this):
    set -U __fish_config_op_logging on

    # Full minimal mode — disable all six categories at once:
    set -U __fish_config_opinionated 0

    # Re-enable everything (except C5 logging, which stays opt-in):
    set -Ue __fish_config_opinionated

    # Minimal mode but keep the greeting:
    set -U __fish_config_opinionated 0
    set -U __fish_config_op_greeting 1
    # (erase both to go back to full-flavor defaults)

For an interactive alternative to setting these variables by hand, run
config-settings — a full-screen TUI that flips any category (including C5
logging) on or off, per session or universally. See its entry in Section 5.

NOTE:
  - Command shadows (rm, cat, ls, ...) react immediately; conf.d-level components (bindings, prompt, abbreviations, hooks) take effect in new shells.
  - With aliases disabled, rm falls back to bare `command rm` — files are deleted permanently, not trashed.
  - Disabled integration commands (spwin, tab, split, hist, logs, upgrade) print an error naming the variable that disabled them.
  - On CachyOS, the distro fish config's own aliases, history override, and bang-bang bindings are stripped per category as well.

### Component Reference

The following tables detail every component in each category. Use this
reference to understand exactly which behaviors change when you toggle a
category variable.

#### C1 — Command Shadows

Disabling __fish_config_op_aliases restores standard system behavior for
all of these commands.

    Command / Alias    Active behavior                       Disabled fallback
    ───────────────────────────────────────────────────────────────────────────
    ls                 eza -l -a --icons --hyperlink          system ls
    cat                bat syntax-highlighted; dirs → ls      /usr/bin/cat
    cd                 zoxide frecency-based navigation        fish builtin cd
    rm                 moves files to trash (recoverable)     command rm (permanent)
    less               $PAGER → ov → less → more → cat       system less
    du                 duf (disk overview) or dust (dir tree)  system du
    top                btop resource monitor                  system top
    ping               prettyping --nolegend animation        system ping
    ssh                kitten ssh in Kitty terminal           system ssh
    rg                 rg --hyperlink-format=kitty            system rg
    mkdir              verbose path-tree display on creation  mkdir -p silently
    bash               XDG bashrc + $SHELL reset on exit      system bash
    history            timestamps prepended to every entry    fish builtin history
    cp / mv            forced -i confirmation prompt          cp / mv unmodified
    wget               forced --continue (resume downloads)   system wget
    grep/fgrep/egrep   forced --color=auto                    system grep variants
    dir / vdir         forced --color=auto                    system dir / vdir
    help config        intercepts "help config" → config-help  fish builtin help
    claude             auto-links AGENTS.md as CLAUDE.md before launch  command claude
    edit               multi-editor launcher (GUI/term + fallbacks)  $EDITOR/nvim/nano/vi

When C1 is disabled, `rm` uses bare `command rm` with no wrapper — files
are permanently deleted, not trashed. There is no intermediate safety net.

#### C2 — Startup Side-Effects

These run automatically without any user action. Disabling
__fish_config_op_autoexec prevents all of them.

    Component                  Trigger              What it does
    ───────────────────────────────────────────────────────────────────────────
    Fisher bootstrap           First shell only     Downloads and installs fisher
    Fisher update              After bootstrap      Installs all fish_plugins entries
    Catppuccin Mocha theme     First shell only     Applies theme via fish_config
    paru wrapper               Every startup        Writes ~/.local/bin/paru wrapper
    yay wrapper                Every startup        Writes ~/.local/bin/yay wrapper
    Python venv activation     On every cd          Sources .venv/bin/activate.fish
    WakaTime command hook      On every command     Reports to WakaTime API
    Auto-pull fast-forward     On entering a repo   Background ff-only git pull
    user-dots symlink          Every startup        Links $__fish_config_dir/user-dots
                                                    to $__fish_user_dots_path

When C2 is disabled: no Fisher install, no theme application, no paru/yay
wrapper generation, no automatic venv activation, no WakaTime reporting,
no auto-pull (the PWD handler is never registered), and the user-dots
convenience symlink is not created. The symlink is git-ignored and only ever
managed as a symlink — a real file or directory at that path is left untouched.
The symlink has its own opt-out independent of C2: set __fish_user_dots_symlink
to a falsy value (or toggle "Dots link" off on the config-settings Paths page)
to stop generating it and remove any existing link — honoured even when C2 is
enabled. Managed by the __fish_user_dots_link helper.
The first-run completion marker (__fish_config_first_run_complete) is still
set so the init does not re-run on subsequent shells.

Python venv activation fires on every directory change. If a directory uses
direnv (.envrc present), direnv takes priority and auto-venv is skipped for
that directory.

Auto-pull fast-forwards opted-in repositories in the background when you cd
into them. The fish-config repo is always covered; other repos are added with
the `auto-pull` command (see its entry in the functions reference). It only
ever fast-forwards a clean repo whose branch has an upstream — never rebases,
merges, or overwrites work — so it is a no-op on dirty trees, divergent
branches, or repos without a remote. The handler fires once per repo entry
(not on every sub-directory cd). The registry is machine-local at
`$__fish_user_dots_path/auto-pull.list` (defaults to `~/.config/.user-dots/fish/auto-pull.list`) and is never committed.

#### C3 — Key and Environment Overrides

These change fundamental shell behavior: how keys work, which pager opens,
and what the prompt looks like. Disabling __fish_config_op_overrides removes
all of them.

    Override                  What it replaces or sets
    ───────────────────────────────────────────────────────────────────────────
    Vi mode                   fish_vi_key_bindings replaces default Emacs mode
    PATH setup                Prepends custom bin directories to the PATH
    exit → smart_exit         exit wrapper that captures scrollback before closing
    PAGER=ov                  ov used by git, man, and all $PAGER-aware tools
    EDITOR=nvim               nvim fallback to vi for git commit, etc.
    GPG_TTY                   Sets GPG_TTY to current terminal tty
    MANPAGER=bat pipeline     man pages rendered with syntax highlighting
    CDPATH=. ~/projects ~     bare dir names resolve against ~/projects and ~
    Bang-bang system          ! and $ keys expand history; !^, !*, !-N, !?str?,
                              ^old^new abbreviations; six expand_bang_* helpers
    Autopair                  ( [ { " ' auto-close to (), [], {}, "", ''
    Puffer key intercepts     . ! $ * keys intercepted for smart expansion
    Starship prompt           fish_prompt replaced by Starship + OSC 133 markers
    Catppuccin colors         30+ fish_color_* variables set to Mocha palette
    FZF_DEFAULT_OPTS          FZF themed to Catppuccin Mocha colors
    Right prompt              fish_right_prompt: exit code (on failure) + dim timestamp; always rendered; Docker context added when starship+C3 active

The bang-bang system spans key_bindings.fish, abbr.fish, puffer.fish, and
six expand_bang_*.fish functions. All are gated together — disabling C3
removes the entire bang-expansion system at once.

When C3 is disabled, `exit` falls back to `builtin exit` with no scrollback
capture, no Kitty IPC, and no file I/O on exit. The scrollback capture block
is independently controlled by C5 (see below).

#### C4 — Terminal and Tool Integration

These features couple the shell to specific external tools. Disabling
__fish_config_op_integrations disables all of them.

    Component                  Requires
    ───────────────────────────────────────────────────────────────────────────
    ~60 Kitty/WezTerm abbrs    Active Kitty or WezTerm session
      (:w, :wv, :wh, :t, etc.)
    Done desktop notifications  Graphical desktop with a notification daemon
    spwin                      Kitty or WezTerm
    tab                        Kitty, WezTerm, or Konsole
    split                      Kitty or WezTerm
    hist                       fzf + wl-copy (Wayland clipboard)
    logs                       fzf + ov; reads from ~/.terminal_history/
    upgrade                    paru or yay (Arch Linux only)
    WakaTime hook              wakatime CLI and a configured API key

Disabled integration commands (spwin, tab, split, hist, logs, upgrade) print
a colored error to stderr naming the variable that disabled them rather than
silently failing.

#### C5 — Logging and Capture

Five components capture shell output to disk. Unlike every other category,
C5 is opt-in: it stays off until __fish_config_op_logging is set to an
explicit truthy value, and a truthy master switch does not enable it. While
it is off, all capture is skipped and the logging wrappers are removed.

    # Turn it on (persistently, in every shell):
    set -U __fish_config_op_logging on

    # Turn it back off:
    set -U __fish_config_op_logging off     # or: set -Ue __fish_config_op_logging

    Component               What it captures
    ───────────────────────────────────────────────────────────────────────────
    Scrollback capture      Terminal session output saved to:
                            ~/.terminal_history/scrollback_YYYY-MM-DD_HH-MM-SS.log
    tmux pane capture       Continuous pane stream via pipe-pane, saved to:
                            ~/.terminal_history/tmux_<session>-w<win>-p<pane>_YYYY-MM-DD_HH-MM-SS.log
    zellij pane capture     Pane scrollback snapshot on shell exit, saved to:
                            ~/.terminal_history/zellij_<session>-p<pane>_YYYY-MM-DD_HH-MM-SS.log
    paru wrapper            All paru/AUR output captured to:
                            ~/.terminal_history/paru_YYYY-MM-DD_HH-MM-SS.log
    yay wrapper             All yay/AUR output captured to:
                            ~/.terminal_history/yay_YYYY-MM-DD_HH-MM-SS.log
    Kitty watcher           watcher.py captures scrollback when Kitty closes

NOTE: **Turning off logging does not delete any existing logs.**  
They remain in `$SCROLLBACK_HISTORY_DIR` (defaults to: `~/.terminal_history/`)
until you remove them manually.

The tmux capture starts automatically when fish launches inside any tmux
pane ($TMUX is set). It uses tmux's native pipe-pane to stream all pane
output directly to disk without an intermediate process. Each fish shell
session gets its own log file; a new log is created on each shell start
(including exec fish and new splits). Before each new log, the oldest
tmux_*.log files are pruned (by modification time) to keep the total within
SCROLLBACK_HISTORY_MAX_FILES, matching the paru/yay wrapper behaviour.

The zellij capture works differently: Zellij has no live output-streaming
facility like pipe-pane, so the log is taken as a one-shot snapshot when the
shell exits, via `zellij action dump-screen --full --ansi` (the --ansi flag
preserves color). The dump is captured on the fish process's stdout and
written to the log file by fish itself (not via `--path`, which would make the
zellij server write the file). A fish_exit handler (registered whenever
$ZELLIJ is set) writes the pane's full scrollback and then prunes old
zellij_*.log files the same way. Because the capture happens at exit, toggling
__fish_config_op_logging takes effect on the next exit with no restart or
sentinel coordination needed — the C5 guard is re-checked when the handler
fires.

LIMITATION — zellij capture only fires on a clean shell exit (typing `exit`,
Ctrl-D, or a logout), because that is when the fish_exit handler runs. It does
NOT capture when you close a pane or quit zellij through zellij itself:

  - Closing a pane signals the shell and tears the pane down concurrently, so
    even if the handler runs, `dump-screen` may find the pane buffer already
    gone.
  - Quitting zellij kills the zellij server, and `dump-screen` needs a live
    server to read from — there is nothing left to snapshot.

This is a structural difference from tmux, NOT a bug. tmux streams pane output
to disk continuously via pipe-pane, so whatever was printed is already saved
no matter how the pane dies. Zellij can only snapshot, and the only reliable
snapshot point from the shell is a clean exit. To guarantee a zellij pane is
logged, end the session with `exit` or Ctrl-D rather than zellij's close-pane
or quit actions.

The Kitty watcher is managed by the kitty-logging command: it symlinks the
watcher (fish-config-watcher.py) into the Kitty config directory and wires it
into kitty.conf via a managed block. Inside Kitty, a non-blocking
per-session reminder points first-time users at `kitty-logging install` until
they install or run `kitty-logging dismiss`; the reminder is itself gated on
C5, so it stays silent until you enable logging. Install affects new Kitty
windows only; runtime disable is still handled by the .logging_disabled
sentinel.

Logging coordination via sentinel file

C5 uses a sentinel file to synchronize state between the shell and
out-of-process components (the Kitty watcher and all running shells):

    ~/.config/fish/.logging_disabled

Because C5 is off by default, the sentinel is present on a fresh install —
the startup sync in conf.d/logging-events.fish reconciles it on every shell
start, so it appears without any action on your part.

Disabling __fish_config_op_logging (or leaving it unset):
  1. Creates the sentinel immediately in every open shell.
  2. Removes ~/.local/bin/paru and ~/.local/bin/yay logging wrappers;
     bare /usr/bin/paru and /usr/bin/yay are used instead.
  3. Kitty's watcher.py reads the sentinel on each save attempt and
     skips capture — no Kitty restart required.
  4. smart_exit stops saving scrollback logs.
  5. Stops tmux pipe-pane capture in every open fish shell inside tmux.

Enabling __fish_config_op_logging:
  1. Removes the sentinel in every open shell.
  2. Regenerates paru/yay logging wrappers in ~/.local/bin/.
  3. Kitty watcher resumes capture on the next session exit.
  4. Restarts tmux pipe-pane capture in every open fish shell inside tmux.

Changes propagate to all running shells through an event handler that fires
whenever __fish_config_op_logging changes — no shell restart needed.

Note: C3 and C5 compose independently. C3 controls whether the smart_exit
wrapper is active at all; C5 controls only the scrollback-capture block
inside it. With C3 disabled, exit is plain builtin exit regardless of C5.

#### C6 — Greeting and First-Run UI

    Component                  What it shows
    ───────────────────────────────────────────────────────────────────────────
    First-run welcome banner   One-time message on first interactive session
    fish_greeting override     Empty function defined late in config.fish to
                               suppress distro greetings (e.g. CachyOS sets
                               fish_greeting to fastfetch by default)

When C6 is disabled, no greeting is printed by this config. Any greeting
set by the distro or other configs runs normally — this config simply does
not override it.

## Prompt and Theme

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
