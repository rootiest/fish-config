# Design: Header-Driven `--help`

**Date:** 2026-09-07
**Status:** Proposed
**Job:** 3 of the parallel improvement effort (fork of `08e66c8`, branch `work`)

---

## Overview

`functions/CLAUDE.md` requires every user-facing function to accept `-h`/`--help`
and print a formatted menu to stdout, "unless it strictly wraps another tool's
help." Most do not.

The documentation those menus would contain already exists. Every documented
function carries a man-page-style comment header — `SYNOPSIS`, `DESCRIPTION`,
`ARGUMENTS`, `EXIT STATUS`, `RETURNS`, `EXAMPLE`, `NOTES` — which
`2026-07-26-function-headers-as-ssot-design.md` established as the SSOT for
Section 5 of the manual, and which `docs/verify-manual.py` already enforces.

The header is written; it is simply not reachable at runtime. This spec makes it
reachable with one renderer function and one line per call site. It authors no
new documentation prose, and it changes nothing in the docs build pipeline.

### Why not write the menus

Writing a menu per function creates a second copy of facts the header already
holds, in a place no verifier checks. The 40 functions in scope would cost
roughly 600 lines of `echo` that immediately begin drifting from the header that
generates the manual. The 30 functions that already have hand-rolled menus are
the evidence: several of them already say things their headers do not.

---

## Measured Baseline

Taken 2026-09-07 against `functions/` at `08e66c8`. Counts come from
`manualtools.parse_functions()`, not from grep, so they match what the manual
actually publishes.

| Fact | Value |
|---|---|
| `.fish` files in `functions/` | 185 |
| Files with a `# CATEGORY` comment | 110 |
| Functions the parser actually publishes | **109** |
| ...that print their own help menu today | **30** |
| ...that do not | **79** |
| Of those 79: exempt (see §4) | 39 |
| Of those 79: to convert | 40 |
| `fish tests/run-tests.fish` | 317/317 pass |
| `python3 docs/verify-manual.py` | 74/74 pass |

The job brief quoted 110 / 34 / 78. Three corrections, all verified:

- **110 → 109.** `zoxide.fish` carries two `# CATEGORY` blocks, but both resolve
  to `_zoxide_*` names, which `parse_functions` drops as private. It publishes
  nothing.
- **34 → 30.** The grep for `--help` counted `fisher.fish` and
  `_fzf_configure_bindings_help.fish` (neither is a published function), and
  `jr.fish` and `yt-dlp.fish`, which mention `--help` only inside their comment
  headers and do not handle it in the body.
- **78 → 79.** `split` matched the grep because it uses `-h` for
  `--horizontal`. It has no help menu, and its `-h` is spoken for. It belongs in
  the target set as a special case (§4.3).

### Pre-existing defects found, not fixed here

- **`dops.fish` defines `function docker`, not `dops`.** The single header block
  in that file resolves to the file stem, so the manual publishes an entry for
  `dops` — a function that does not exist — while `docker` is undocumented. The
  renderer resolves this correctly by accident (§3.2), but the manual entry
  stays wrong. Out of scope: fixing it means authoring header content.
- **`sponge_filter_secrets.fish`** has a blank line between its header block and
  its `function` line. The renderer tolerates it (§3.2); noted because it is the
  only file that does.

---

## 1. Requirements

1. Every non-exempt published function responds to `-h` and `--help` with its own
   documentation on **stdout**, exit 0.
2. Functions that pass `--help` through to a wrapped tool keep doing so.
3. `fish tests/run-tests.fish` stays at 317/317 plus the new checks.
4. `python3 docs/verify-manual.py` passes unchanged.
5. A test fails when a new user-facing function ships without help.
6. The docs build pipeline is not modified.
7. No header documentation content is added or rewritten.

---

## 2. Renderer: `__fish_help_header`

One new autoloaded function, `functions/__fish_help_header.fish`.

```fish
__fish_help_header <name> [args...]
```

It returns **1 — and prints nothing — only when `args[1]` is not a help flag.**
In every other case it prints something useful to stdout and returns 0. That
asymmetry is the safety-critical invariant: a return of 1 means "carry on with
the real work", so a parse failure must never produce it. `upgrade --help`
falling through to `paru -Syu --noconfirm` is the failure this rule exists to
prevent.

### 2.1 Call site

One line, as the **first statement of the function body**, above any opinionated
guard:

```fish
function poke --description 'touch with automatic parent directory creation'
    __fish_help_header (status current-function) $argv; and return 0
    ...
end
```

`status current-function` is evaluated in the caller's scope, so it yields the
caller's name. Placing the line above the C1/C4 guard means documentation stays
reachable when a component is disabled, and guarantees nothing side-effecting
runs before the flag is inspected.

The `; and return 0` form leaves `$status` at 1 when no help flag was passed.
No function in scope reads `$status` as its first act, so this is inert — but
new call sites must not be added above a `$status` read.

### 2.2 First-argument-only interception

The renderer fires only when **`$argv[1]`** is `-h` or `--help`. Not anywhere in
`$argv`.

This is not a simplification, it is a correctness requirement. `bkg`,
`wake-lock`, `split` and `spwin` take a command to run as their arguments.
Scanning all of `$argv` would make `wake-lock rsync --help` print `wake-lock`'s
help instead of running rsync. First-argument-only is also the pattern
`jobrunner` and `rand_string` already use.

The 30 existing argparse-based menus keep accepting `--help` in any position.
This spec does not touch them (§5).

### 2.3 Output format

Matches `config-help`, the richest and most recent house menu:

```
<name>                      bold

USAGE                       bold brblue
  <SYNOPSIS lines>          two-space indent, deeper indent preserved

DESCRIPTION
  ...

ARGUMENTS
  ...
```

- `SYNOPSIS` renders as `USAGE`; `EXAMPLE` renders as `EXAMPLES`. Every other
  label renders verbatim.
- `CATEGORY`, `COMPONENT` and `DEPENDENCIES` are build metadata and are skipped.
- `EXIT STATUS`, `RETURNS` and `NOTES` render when present.
- Blank lines inside a section are preserved (20 headers have multi-paragraph
  `DESCRIPTION`s); trailing blanks are trimmed, mirroring
  `manualtools._trailing_blanks`.
- **Body text is not colorized.** Only the name and the section headings carry
  color. Guessing which words in a `DESCRIPTION` are flags or commands is a
  heuristic with no upside; `config-help`'s hand-tuned coloring stays hand-tuned.

### 2.4 Degraded output

If `functions -D` yields no readable file, or the file holds no renderable
section, print the function name, its `--description`, and a pointer to
`help config <name>` — then return 0. Never return 1.

---

## 3. Where the help text comes from

### 3.1 Decision: parse the `.fish` source at call time

Rejected alternatives:

- **Read the generated `docs/fish-config.md`.** It is committed and
  pre-formatted, but it is a *generated* artifact: a header edited without a
  docs rebuild makes `--help` lie, which is the exact drift this job exists to
  remove. It also costs a 163 KB scan and a `### <name>` heading match that can
  collide with prose headings elsewhere in the manual.
- **Precompute a fish data file at build time**, mirroring the component
  registry. This is the fastest option at runtime, but it adds a build artifact,
  a new staleness class, and a step in the docs pipeline — which requirement 6
  forbids touching.
- **Reuse `config-help`.** It is a pager launcher over the whole manual; it
  cannot emit one function's entry to stdout, and bending it into that shape
  would cost more than the renderer.

Source parsing wins because the source cannot be stale, the parse is ~15 lines
of `string match`, and the cost is one small file read on a keypress — never at
startup.

### 3.2 Parsing rule

Locate `function <name>` in the file, then walk **backwards** collecting the
contiguous run of `#` lines above it (skipping a blank separator line, for
`sponge_filter_secrets`). Within that run, apply `manualtools`' own grammar:

- `^#\s+([A-Z][A-Z ]*[A-Z])\s*$` starts a section.
- Any other `#` line is body: strip `#`, then strip exactly three leading spaces
  if present, so deeper indentation in nested `ARGUMENTS` tables survives.
- `#` lines before the first label (the copyright preamble) are ignored.

Backward-walking from the `function` line replaces `manualtools._block_identity`
and is strictly more accurate at runtime: it resolves the three multi-header
files that publish a function (`fish-deps`, `gi`, `y`) correctly, and it gives
`docker` its real header in `dops.fish` where the Python parser attributes that
block to the file stem.

### 3.3 Verified mechanics

Proven in fish 4.9.1, not assumed. An autoloaded function calling
`(status current-function)` and `functions -D` on the result resolves to its own
defining file, both when called directly and when called from another function:

```
status current-function: probefn
functions -D self:       .../functions/probefn.fish
status filename:         .../functions/probefn.fish
```

Called *inside* the renderer, `status current-function` returns `__fish_help_header`
and `status stack-trace` returns the caller's path only as `~`-abbreviated prose.
Hence the name is passed as an argument rather than discovered. A working
prototype rendered `poke --help` in the format of §2.3 and left `poke`'s normal
path untouched.

---

## 4. Classification of the 79

The exemption in `functions/CLAUDE.md` is "strictly wraps another tool's help."
Applied literally it splits into two classes, plus one collision case.

**EXEMPT-A — shadow or pass-through.** The function shadows a real same-named
binary, or its entire body forwards `$argv` to one named tool. `ls --help` must
reach `ls`. Intercepting is a regression, and for the C1-guarded shadows it also
breaks the disabled-fallback contract, where the bare tool is supposed to answer.

**EXEMPT-B — not a command.** Invoked by fish, never typed. Published in the
manual, but `--help` is meaningless.

### 4.1 EXEMPT-A (35)

| Function | Reason |
|---|---|
| `agy` | Shadows `agy`; body ends in `command agy $argv`. |
| `antigravity-ide` | Shadows `antigravity-ide`; only filters one stderr line. |
| `bash` | Shadows `bash`; adds `--rcfile`, forwards the rest. |
| `cat` | Shadows `cat`; C1 guard falls back to `command cat $argv`. |
| `cdi` | Whole body is `zi $argv`; zoxide owns the help. |
| `cffetch` | `clear` then `fastfetch $argv`. |
| `cheat` | `command cheat -c $argv`, else `tldr`/`man`. |
| `claude` | Shadows `claude`; body ends in `command claude $argv`. |
| `clone` | Whole body is `clone-in-kitty $argv`. |
| `clonet` | Whole body is `clone-in-kitty --type=tab $argv`. |
| `config-toggle` | Deprecated alias; forwards to `config-settings`, which has help. |
| `copy` | Whole body is `command cp $argv` with one directory special case. |
| `dops` | The file defines `docker`, which shadows `docker`. |
| `du` | Shadows `du`; unmatched args reach `command du`. |
| `dusize` | `du -sh $argv[1]` through the `du` shadow. |
| `fast-cli` | Whole body is `command fast $argv`. |
| `ffetch` | Whole body is `fastfetch $argv`. |
| `gitui` | `command gitui -t frappe.ron $argv`. |
| `gitup` | Its own `SYNOPSIS` is `gitup [args...]`, forwarded to `git fetch`. |
| `jr` | Whole body is `jobrunner $argv`; `jobrunner` has a help menu. |
| `joplin` | Whole body is the real `joplin` binary with `NODE_OPTIONS` set. |
| `less` | Shadows `less`; resolves a pager and forwards `$argv`. |
| `ls` | Shadows `ls`; forwards to `eza`/`lsd`/`command ls`. |
| `mkdir` | Shadows `mkdir`; any flag argument goes to `command mkdir -p`. |
| `mv` | Shadows `mv`; falls through to `command mv $argv`. |
| `paste` | Shadows coreutils `paste`; forwards `$argv` to `wl-paste`/`xclip`. |
| `ping` | Shadows `ping`; forwards to `prettyping` or `command ping`. |
| `rawfish` | Whole body is `env NO_TMUX=1 fish $argv`. |
| `rg` | Shadows `rg`; adds one flag under Kitty, forwards the rest. |
| `rm` | Shadows `rm`; unmatched args reach `command rm $argv`. |
| `search` | Whole body is `$aur $argv` (paru or yay). |
| `ssh` | Shadows `ssh`; forwards to `kitten ssh` or `command ssh`. |
| `top` | Shadows `top`; forwards to `btop` or `command top`. |
| `view` | Shadows vim's `view`; whole body is `nvim -R $argv`. |
| `yt-dlp` | Shadows `yt-dlp`; injects defaults, forwards `$argv` last. |

### 4.2 EXEMPT-B (4)

| Function | Reason |
|---|---|
| `fish_prompt` | Prompt hook; fish calls it, users never do. |
| `fish_right_prompt` | Prompt hook. |
| `fish_mode_prompt` | Prompt hook; body is empty. |
| `sponge_filter_secrets` | `sponge` plugin filter callback, invoked per command. |

### 4.3 CONVERT (40)

All take the standard call site of §2.1 unless noted.

| Function | Reason it is not exempt |
|---|---|
| `bd-pull` | Own Gitea/Beads logic; `$argv[1]` is a repo slug. |
| `bkg` | Command runner; `$argv` is a command, not flags. First-arg rule applies. |
| `branch` | Own git logic; `branch --help` currently feeds `--help` to `git checkout -b`. |
| `check_fish_deps` | Ignores `$argv`; runs `fish-deps status`. |
| `claude-docs` | Ignores `$argv`; fires a fixed prompt. |
| `claude-pr` | Ignores `$argv`; fires a fixed prompt. |
| `cleanup` | Ignores `$argv`; `--help` currently runs `sudo pacman -Rns`. |
| `fast` | Ignores `$argv`; placeholder that prints a notice. |
| `fc` | Own history logic; `--help` currently becomes a history search term. |
| `fish-deps` | **Reuse:** wire `case -h --help` to the existing `__fish_deps_help`, return 0. Today `--help` hits `case '*'`, prints "Unknown subcommand", exits 1. |
| `fzf-update` | Ignores `$argv`; `--help` currently clones and installs fzf. |
| `gip` | Ignores `$argv`. |
| `gip4` | Ignores `$argv`. |
| `gip6` | Ignores `$argv`. |
| `hist` | Ignores `$argv`; opens an fzf picker. |
| `lD` | Not a binary; three-branch body whose value is the `--only-dirs` preset. |
| `ld` | Ignores `$argv`; launches lazydocker with a computed `DOCKER_HOST`. |
| `limine-edit` | Ignores `$argv`; `--help` currently runs `sudoedit` and re-enrolls Limine. |
| `lock` | Ignores `$argv`; `lock --help` currently locks the screen. |
| `lsr` | Not a binary; value is the reverse-time preset. |
| `lss` | Not a binary; value is the size-sort preset. |
| `lstree` | Not a binary; value is the recursive-tree preset. |
| `lt` | Not a binary; value is the depth-2 tree preset. |
| `ltr` | Not a binary; value is the reverse-time preset. |
| `lx` | Not a binary; value is the extension-sort preset. |
| `parur` | Ignores `$argv`; opens an fzf package picker. |
| `poke` | Own logic; `--help` would be created as a file. |
| `ports` | Ignores `$argv`; runs `sudo lsof`. |
| `qr` | `--help` would be encoded into a QR code. |
| `sbver` | Own `--brief` flag; runs `sudo sbctl verify`. |
| `screensleep` | Ignores `$argv`; `--help` currently blanks the display. |
| `split` | **`--help` only, no `-h`.** Its own `ARGUMENTS` documents `-h, --horizontal`. |
| `spwin` | Own terminal dispatch; first-arg rule protects `spwin <cmd> --help`. |
| `steam-dl` | Ignores `$argv`. |
| `sudo-toggle` | Ignores `$argv`; `--help` currently rewrites `/etc/sudoers.d`. |
| `swapstat` | Ignores `$argv`. |
| `tab` | Own terminal dispatch; first-arg rule protects the forwarded command. |
| `tmux-clean` | Ignores `$argv`; `--help` currently kills tmux sessions. |
| `upgrade` | Ignores `$argv`; `--help` currently runs `paru -Syu --noconfirm`. |
| `wake-lock` | Command runner; first-arg rule protects `wake-lock <cmd> --help`. |

Eight of these currently perform a destructive or irreversible action when handed
`--help`, because they ignore `$argv` entirely and just run: `cleanup`
(`sudo pacman -Rns`), `fzf-update` (clone and install), `limine-edit` (`sudoedit`
and re-enroll), `lock` (locks the session), `screensleep` (blanks the display),
`sudo-toggle` (rewrites `/etc/sudoers.d`), `tmux-clean` (kills tmux sessions) and
`upgrade` (`paru -Syu --noconfirm`). For these, converting is a safety fix before
it is a documentation one.

`split` is the only `-h` collision in the whole set; every other CONVERT function
was checked and uses `-h` for nothing.

---

## 5. The 30 existing menus stay

Not converted in this job. The risk is asymmetric:

- Three of them carry content that **does not exist in any header**, so
  conversion would delete documentation: `config-help`'s ov navigation keys and
  pager fallback chain, `qc`'s appended `aichat --help`, `superpowers`' inline
  usage block. Recovering them means authoring header prose, which requirement 7
  forbids.
- Thirteen use `argparse`/`_flag_help` and accept `--help` in any position.
  Moving them to the first-argument-only rule of §2.2 is a real behavior change
  for menus people already use.
- No acceptance criterion requires it. The duplication they represent is
  pre-existing and static — it does not grow as new functions land, because new
  functions will use the renderer.

Thirty conversions is thirty independent chances to change output somebody
relies on, bought for no test. Recommended as a separate follow-up branch, where
each diff can be reviewed against its own before/after output.

---

## 6. Testing

Two additions to `tests/functional.fish`, which runs inside the sandboxed loaded
session where `functions -D` resolves to the sandbox copy.

**`test_help_renderer`** — behavioral. Renders a fixture function with a known
header and asserts the section order, the `SYNOPSIS`→`USAGE` rename, indentation
survival, and exit 0. Then spot-checks two real, side-effect-free functions
(`poke`, `gip4`) end to end. Runs under `TERM=dumb`, where `set_color` emits
nothing, so assertions match plain text.

**`test_every_user_facing_function_has_help`** — the guard required by
acceptance 5. For each function published by the header parser, assert its body
contains a help entry point (`__fish_help_header`, `_flag_help`, or a
`-h`/`--help` branch) *or* appears in an explicit exempt list.

The exempt list lives in `tests/functional.fish` as one array with a one-line
comment per entry, seeded from §4.1 and §4.2. Rejected: a `# NOHELP` marker
comment in each exempt file — 39 file edits for no runtime benefit, and a marker
is the kind of thing that gets copy-pasted into a new function and silently
exempts it. A central list makes adding an exemption a reviewable act.

The wiring check is deliberately static. Running all 40 functions with `--help`
would be a stronger test, but it executes `upgrade`, `sudo-toggle` and
`limine-edit` on the CI machine, and it is precisely wrong when the code is
broken — the case the test exists to catch. The renderer's behavior is proven
once against a fixture; the wiring is proven by inspection across all 40.

---

## 7. Line delta

| Change | Lines |
|---|---:|
| `functions/__fish_help_header.fish` (with license + header) | ~55 |
| 39 call sites × 1 line | +39 |
| `fish-deps` `case -h --help` | +2 |
| `tests/functional.fish` (2 tests + exempt list) | ~60 |
| Hand-rolled menus deleted | 0 |
| **Net** | **~+156** |

The number that matters is not in the table: 40 menus not written. At the ~15
lines the existing menus average, hand-writing them would have cost ~600 lines
of `echo` and a permanent second copy of the manual.

---

## 8. Risks accepted

- **First-argument-only interception** means `poke somefile --help` does not
  print help. Correct for command runners, mildly surprising elsewhere. Accepted:
  the alternative silently breaks `wake-lock rsync --help`.
- **Uncolored body text.** Generated menus will look plainer than the
  hand-tuned ones. Accepted over a guessing heuristic.
- **A header missing `ARGUMENTS`** yields a menu without an arguments section.
  `verify-manual.py` enforces only `SYNOPSIS`, `DESCRIPTION` and `EXAMPLE`.
  Filling the gaps is authoring prose — out of scope. Note them, do not write them.
- **The seven `ls` variants** (`lD`, `lsr`, `lss`, `lstree`, `lt`, `ltr`, `lx`)
  currently pass `--help` to `eza`, incidentally. After conversion they print
  their own preset's documentation and `eza --help` reaches eza directly. This
  is the largest judgment cluster in §4.3 and the most likely place for the
  classification to be wrong.
- **`functions/CLAUDE.md` will still read as violated.** Its one-line rule names
  only the wrapper exemption, not the prompt-hook class. A two-line amendment is
  proposed separately; this spec does not change it.
