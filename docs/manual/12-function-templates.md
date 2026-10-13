---
title: Function Templates
manTitle: 12. FUNCTION TEMPLATES
sidebar:
  order: 16
helpKeywords:
- fish-template
- templates
- function-templates
---

`fish-template` builds your own fish functions from templates, without
writing any code. You answer a few questions and it writes a finished,
documented function with its own `--help`, saved where fish finds it in
every new shell.

## What it is

A function made by fish-template has two parts you choose:

- A **target**: what runs. One command, the first installed of several
  commands, a list of steps, a set of subcommands, a long command line
  with slots for your arguments, a different command line on each host
  or operating system, or a jump to a directory.
- Any number of **modifiers**: how it runs. Extra arguments, environment
  changes, a confirmation question, a fixed directory, retries, a time
  limit, a log file, a desktop notification.

Your answers are kept inside the function as its **recipe**, so you can
change them later, rebuild the function when the templates improve, or
copy the recipe to another machine.

## Quick start

Run the guided wizard and answer its questions:

    fish-template new

Or give everything on the command line and skip the questions:

    fish-template new rg --target command --set command_cmd=rg --with args --set args_prepend=--smart-case --yes

Start from a ready-made recipe (a preset). The wizard offers the
preset's answers as defaults; afterwards, `rmr --help` describes the new
function:

    fish-template new rmr --preset safe-rm

See what is available, and what a template asks for:

    fish-template list
    fish-template info retry

## The wizard step by step

`fish-template new` asks only for what you have not already given with
--target, --with, --set or --from:

1. Function name: letters, digits and _ . + - (not as the first
   character). Fish keywords such as set or end are refused.
2. Target: picked from a menu when fzf is installed, otherwise typed.
3. Modifiers: a space-separated list. Type ? to list the modifiers that
   work with your target, or - for none.
4. Each setting of the target and the modifiers, in turn. The value in
   square brackets is the default: press Enter to keep it, or type - to
   clear it. Settings that take several lines (sequence steps,
   subcommands) are entered one per line, ending with a blank line.
5. Preview the function? Shows the generated code.
6. Write it? Answer n and nothing is written.

With --yes nothing is asked: every setting you did not give takes its
default, and a required setting with no value is an error. --dry-run
prints the function instead of writing it.

On the command line, a list setting takes space-separated words in one
--set (quote the whole thing), and a line setting takes one entry per
--set, repeated:

    fish-template new edit-config --target command --set 'command_cmd=nvim -p' --with in-dir --set indir_dir=~/.config/fish --yes

## How stacking works

Modifiers always run in a fixed order, whatever order you list them in.
Every generated function is built from these phases:

    Phase    What runs                       Used by
    ───────  ──────────────────────────────  ─────────────────────────────
    guard    The target, then the modifiers  confirm, fallback's search,
                                             snippet's slots, per-host and
                                             per-os matching
    seed     The target                      command, jump
    prepare  The modifiers, in ORDER         in-dir, args, env, timeout,
                                             retry, log
    run      The target, in the retry loop   every target; its output also
                                             goes to the log file with log
    finally  The modifiers, in ORDER         in-dir, notify

ORDER is the fixed position each modifier has: in-dir first, then args,
env, confirm, timeout, retry, log and notify.

So confirm asks before the command or any other modifier does anything,
in-dir changes directory before the command starts and returns you to
where you were afterwards, and notify reports the final result once.

Together, retry, log and notify do what you would hope: each attempt's
output is shown and saved to the log file (with log_mode overwrite, the
file is replaced on the first attempt and the later attempts add to it),
the next attempt waits retry_delay seconds, and one notification at the
end says whether the last attempt succeeded.

Functions can also call each other. A sequence step or a dispatcher
subcommand can be any command, including a function you made earlier
with fish-template.

## Targets

The catalog in this section and the next two is generated from the
templates/ directory, so it always matches what `fish-template list` and
`fish-template info` show. Defaults are shown exactly as the template
writes them; — means empty.

A function has exactly one target.

<!-- GENERATED: template-targets -->

## Modifiers

Stack any number of modifiers on a target, each at most once. The
Works with line names the targets a modifier accepts.

<!-- GENERATED: template-modifiers -->

## Presets

A preset is a ready-made recipe. Its values are offered as the defaults,
so the wizard still asks and you can change any of them.

<!-- GENERATED: template-presets -->

## Worked examples

Each command here was checked with --dry-run. Leave out --yes to be
asked about anything you want to change.

A deploy script that runs in its project directory, tries up to three
times and tells you when it is done:

    fish-template new deploy --target command --set command_cmd=./deploy.sh --with in-dir,retry,notify --set indir_dir=~/projects/site --set retry_attempts=3 --yes

A safe wrapper that asks before doing something destructive:

    fish-template new git-wipe --target command --set 'command_cmd=git clean -fdx' --with confirm --set 'confirm_prompt=Delete every untracked file?' --yes

Update everything at once, from the update-all preset, or your own list
of steps (here calling the function made by the first line):

    fish-template new update-all --preset update-all --yes
    fish-template new morning --target sequence --set sequence_steps=update-all --set 'sequence_steps=git -C ~/notes pull' --set sequence_on_fail=continue --yes

One command for a project, with subcommands, run in the project
directory, used as proj build, proj test or proj serve:

    fish-template new proj --target dispatcher --set 'dispatcher_subcommands=build=make build' --set 'dispatcher_subcommands=test=make test' --set 'dispatcher_subcommands=serve=python3 -m http.server' --with in-dir --set indir_dir=~/code/proj --yes

proj help, or proj on its own when no default subcommand is set,
lists the subcommands; an unknown
subcommand exits with status 2. Any extra words after the subcommand
are added to the end of its command line.

A short name for a long command line, used as ytmp3 URL. Write {1},
{2} and so on where your arguments go, and {@} for any arguments after
those:

    fish-template new ytmp3 --target snippet --set 'snippet_cmd=yt-dlp -x --audio-format mp3 {1}' --yes

Calling it with fewer arguments than its highest slot, or with extra
arguments when there is no {@}, prints its usage and exits with status
2. Each argument fills its slot as one word, exactly as given: spaces,
quotes, $ and (...) in it are never read as fish code, so an argument
cannot run anything. A snippet runs one program with its arguments, so
it has no pipes or redirections; use sequence for those.

One function that does the right thing on every machine sharing your
user-dots, with a command line per hostname and a default for the
rest. A key can list several hosts as a|b and use * and ? wildcards;
the first matching line wins:

    fish-template new backup --target per-host --set 'perhost_commands=laptop|tablet=restic backup ~/docs' --set 'perhost_commands=nas-*=restic backup /srv' --set 'perhost_default=echo no backup here' --yes

per-os does the same by operating system. A key is a kernel name
(linux, darwin, freebsd) or a Linux distribution's ID from
/etc/os-release (arch, debian, fedora), and a distribution also matches
the ones it is like, so ubuntu matches debian. Put distributions before
linux, since the first match wins:

    fish-template new upgrade-os --target per-os --set 'peros_commands=arch=paru -Syu' --set 'peros_commands=debian=sudo apt upgrade' --set 'peros_commands=darwin=brew upgrade' --yes

With neither a match nor a default, per-host and per-os exit with
status 1, since the same function may work on another machine.

Go to a project and stay there, showing its status. Unlike in-dir, jump
does not take you back afterwards; cd - returns you to where you were:

    fish-template new proj-go --target jump --set jump_dir=~/code/proj --set 'jump_cmd=git status -sb' --yes

## Recipes

Change a function by answering the questions again, with its current
answers as the defaults:

    fish-template edit deploy

Rebuild functions from their recipes, for example after updating this
config brings improved templates:

    fish-template regen deploy
    fish-template regen --all

List the functions you made, and print one's recipe:

    fish-template ls
    fish-template show deploy

To move a function to another machine, save the output of `show` to a
file, copy it over, and build from it there. Values from --from count as
given, so the wizard does not ask for them again:

    fish-template show deploy > deploy.recipe
    fish-template new deploy --from deploy.recipe --yes

A recipe file is only read, never run: fish-template splits its
`set -l` lines into plain words, so nothing in them is expanded or
executed.

## Where functions live

Generated functions are written to the functions/ directory inside your
private user-dots directory, $__fish_user_dots_path (by default
~/.config/.user-dots/fish), one file per function. With `--output DIR`
they are written to DIR instead.

conf.d/user-dots-functions.fish puts that directory first on
$fish_function_path at startup, so the functions autoload in every
shell. It is deliberately not an opinionated component: it does nothing
until the directory exists, and switching it off would silently unload
your own functions.

Because it comes first, a function you make overrides one of the same
name from this config. fish-template warns you when that happens, and
when a name shadows a fish builtin or a command. To undo an override,
delete your file.

## Safety guarantees

- **No surprise overwrites.** `fish-template new` refuses to replace an existing file
  unless you add --force.
- **Only its own files.** edit and regen only touch a file that contains
  both recipe marker lines, each on a line of its own. Anything else is
  reported as not a function made by fish-template and left alone.
- **Recipes are never executed.** Recipes, presets and --from files are
  read as plain words.
- **Checked before installing.** The generated code must define the
  function you named, pass `fish -n` and `fish_indent --check`, and load
  in fish; if any check fails, nothing is installed (or the new file is
  removed again).
- **Atomic writes.** The file is written to a temporary file next to its
  destination and moved into place, so a half-written function never
  appears.
- **Reserved names are rejected.** Fish keywords and builtins that cannot
  be functions (set, end, test, ...) are refused.
- **Shadowing is reported.** You are warned when a name hides a builtin,
  a function or a command.
- **confirm fails closed.** A confirm_only_if pattern is checked when the
  function is generated, and an invalid one is refused. If a pattern ever
  cannot be evaluated, the function asks anyway.

## Troubleshooting

**'set' is a reserved word in fish.** The name is a fish keyword or
builtin that cannot be redefined. Choose another name.

**NAME is not a function made by fish-template.** edit, regen and show
only work on files fish-template wrote. The file was written by hand, or
its recipe marker lines were edited away.

**timeout cannot be used with a sequence target**, or **env_unset needs
a command or fallback target.** The timeout modifier and env_unset run
your command through the external timeout and env programs, which can
only start other programs. Use them with a command or fallback target
that runs a program, not a fish function. If timeout is not installed,
the function warns and runs without a time limit.

**confirm_only_if: not a valid regular expression.** The pattern is a
PCRE2 regular expression, matched against your arguments joined by
spaces. Fix the pattern, or leave it empty to always ask.

**A function named after its command.** When a command target has the
same name as the program it wraps (a function ls that runs `ls -l`), the
function runs the program by its full path, so it never calls itself.
It also leaves --help to the program.

## Writing your own template

Templates are plain fish files under templates/targets/,
templates/modifiers/ and templates/presets/: a few metadata lines, the
settings with a comment above each, and the code fragments for each
phase. See Adding a template in CONTRIBUTING.md for the format; the
catalog above picks up a new template automatically.
