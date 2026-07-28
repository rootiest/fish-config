---
title: C5 — Logging and Capture
---

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

