#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for tab completions: every function that parses options of its
# own -- with `argparse`, or by hand in a `switch` or `contains --` probe --
# must ship a completions/<name>.fish, or be on the allow-list below. Fish
# derives nothing from either, so without a file the flags are simply
# undiscoverable -- and a new function would silently regress that. Every
# subcommand-style function must also offer each of its subcommands.
#
# Also spot-checks a handful of the hand-written completions by asking a
# throwaway --no-config fish what `complete -C` offers with this repo's
# completions/ on its fish_complete_path.
#
# Runs isolated (no `# MODE:` marker).

source (realpath (dirname (status filename)))/lib.fish

# ---- Allow-list ------------------------------------------------------------
# A function that parses options but is exempt from needing a completion file.
# Internal helpers named with a leading underscore are exempt as a class (they
# are never typed by a user); anything else must be listed here BY NAME with a
# reason, so the exemption is a visible decision rather than an omission.
#
#   qc      probes aichat's own --role; its --wraps aichat supplies that
#   yt-dlp  probes yt-dlp's own flags; fish loads yt-dlp's completions by name
set -l allow_list qc yt-dlp

# The options a function parses itself: the flag-shaped labels of its `case`
# lines and the flags it probes with `contains --`, minus -h/--help, which
# every function takes. Reads code lines only, never the doc header.
function _own_options --argument-names file
    set -l code (string match -rv '^\s*#' <$file)
    begin
        string match -r '^\s*case\s.*' -- $code \
            | string match -ar -- "(?<=[\s'\"])--?[A-Za-z][A-Za-z0-9-]*"
        string match -ar -- 'contains\s+--\s+--?[A-Za-z][A-Za-z0-9-]*' $code \
            | string replace -r '^contains\s+--\s+' ''
    end | string match -rv -- '^(-h|--help)$' | sort -u
end

section "option-parsing functions have a completion file"

set -l option_fns
for f in $repo_root/functions/*.fish
    set -l name (string replace -r '\.fish$' '' (path basename $f))
    string match -q '_*' -- $name; and continue
    # Non-comment lines only: a header that merely mentions argparse is no use.
    set -l opts (_own_options $f)
    if set -q opts[1]; or string match -rv '^\s*#' <$f | string match -rq '\bargparse\b'
        set -a option_fns $name
    end
end

check "found option-parsing functions to check" true (test (count $option_fns) -gt 0; and echo true; or echo false)

for name in $option_fns
    contains -- $name $allow_list; and continue
    check "$name has completions/$name.fish" true (test -f $repo_root/completions/$name.fish; and echo true; or echo false)
end

for name in $allow_list
    check "allow-listed $name still parses options" true (contains -- $name $option_fns; and echo true; or echo false)
end

section "subcommand functions complete every subcommand"

# The subcommand table lives in test-help.fish (__help_subcommands), which
# also proves it complete; read it from there rather than keep a copy.
function _help_subcommand_rows
    set -l in_block 0
    for line in (command cat $repo_root/tests/test-help.fish)
        if test $in_block -eq 0
            string match -rq '^set -g __help_subcommands\b' -- $line; or continue
            set in_block 1
            continue
        end
        set -l row (string match -r "^\s*'([^']+)'" -- $line)[2]
        test -n "$row"; and echo $row
        string match -rq '\\\\\s*$' -- $line; or break
    end
end

set -l rows (_help_subcommand_rows)
check "read the subcommand table from test-help.fish" true (test (count $rows) -gt 0; and echo true; or echo false)

# What `complete -C "<line>"` offers, as a flat list of candidates.
#
# fish only autoloads completions/<cmd>.fish for a command it can resolve, and
# the child has no config, so these functions are not defined there. A stub
# function stands in for the command; the completion is what is under test.
# The repo's functions/ is on the path for the helpers completions call.
function _offered --argument-names line
    set -l cmd (string split -f1 ' ' -- $line)
    env TERM=dumb fish --no-config -c \
        "set -g fish_function_path $repo_root/functions \$fish_function_path
        set fish_complete_path $repo_root/completions \$fish_complete_path
        function $cmd; end
        complete -C '$line'" \
        | string split -f1 \t
end

for row in $rows
    set -l words (string split ' ' -- $row)
    set -l fn $words[1]
    check "$fn has completions/$fn.fish" true (test -f $repo_root/completions/$fn.fish; and echo true; or echo false)
    set -l got (_offered "$fn ")
    for sub in $words[2..]
        check "$fn <Tab> offers $sub" true (contains -- $sub $got; and echo true; or echo false)
    end
end

section "--wraps targets are commands"

# --wraps takes a command line, expanded by nothing: a quoted ~ or $VAR stays
# literal and the wrap silently supplies no completions.
for f in $repo_root/functions/*.fish
    set -l name (string replace -r '\.fish$' '' (path basename $f))
    for target in (string match -rv '^\s*#' <$f | string match -r -- "^\s*function\s.*--wraps[ =]('[^']*'|\"[^\"]*\"|\S+)" | string match -rg -- "--wraps[ =]('[^']*'|\"[^\"]*\"|\S+)")
        set -l bare (string trim -c "'\"" -- $target)
        check "$name --wraps $bare is not a literal path" false (string match -qr '^[~$]' -- $bare; and echo true; or echo false)
    end
end

section "completion files carry the license header"

# Only hand-written files; vendored third-party completions keep their
# upstream attribution instead and carry no SPDX tag (CONTRIBUTING.md).
for file in $repo_root/completions/*.fish
    set -l head (head -n 2 $file)
    string match -q '*Copyright*' -- $head[1]; or continue
    check (path basename $file)" SPDX header" "# SPDX-License-Identifier: AGPL-3.0-or-later" $head[2]
end

section "spot-check offered completions"

set -l got (_offered 'mkrep --serv')
check "mkrep --serv -> --server" true (contains -- --server $got; and echo true; or echo false)

set -l got (_offered 'mkrep --server ')
check "mkrep --server <Tab> offers gitea" true (contains -- gitea $got; and echo true; or echo false)
check "mkrep --server <Tab> offers gitlab" true (contains -- gitlab $got; and echo true; or echo false)
check "mkrep --server <Tab> offers github" true (contains -- github $got; and echo true; or echo false)

set -l got (_offered 'mkrep --')
check "mkrep offers --new-remote" true (contains -- --new-remote $got; and echo true; or echo false)
check "mkrep offers --check-existing" true (contains -- --check-existing $got; and echo true; or echo false)

set -l got (_offered 'logs --category ')
check "logs --category <Tab> offers paru" true (contains -- paru $got; and echo true; or echo false)

set -l got (_offered 'git-clean -')
check "git-clean offers --force" true (contains -- --force $got; and echo true; or echo false)

set -l got (_offered 'git-sweep --')
check "git-sweep offers --dry-run" true (contains -- --dry-run $got; and echo true; or echo false)
check "git-sweep offers --local-only" true (contains -- --local-only $got; and echo true; or echo false)

set -l got (_offered 'gi --')
check "gi offers --custom" true (contains -- --custom $got; and echo true; or echo false)

set -l got (_offered 'agents-cleanup --')
check "agents-cleanup offers --dry-run" true (contains -- --dry-run $got; and echo true; or echo false)
check "agents-cleanup offers --marker-file" true (contains -- --marker-file $got; and echo true; or echo false)

# -w, -f and -i are mutually exclusive: once one is given, the rest are hidden.
set -l got (_offered 'gitignore-scrub --')
check "gitignore-scrub offers --warn alone" true (contains -- --warn $got; and echo true; or echo false)
set -l got (_offered 'gitignore-scrub --warn --')
check "gitignore-scrub --warn hides --force" false (contains -- --force $got; and echo true; or echo false)
check "gitignore-scrub --warn still offers --reset" true (contains -- --reset $got; and echo true; or echo false)

# --install/--uninstall must be the only argument.
set -l got (_offered 'key-crypt --')
check "key-crypt offers --install as the only argument" true (contains -- --install $got; and echo true; or echo false)
set -l got (_offered 'key-crypt --force --')
check "key-crypt hides --install after another flag" false (contains -- --install $got; and echo true; or echo false)

set -l got (_offered 'session-env ')
check "session-env offers install" true (contains -- install $got; and echo true; or echo false)
check "session-env offers desktop" true (contains -- desktop $got; and echo true; or echo false)
set -l got (_offered 'session-env install --')
check "session-env install offers --except" true (contains -- --except $got; and echo true; or echo false)
check "session-env install offers --now" true (contains -- --now $got; and echo true; or echo false)
set -l got (_offered 'session-env desktop install foo --')
check "session-env desktop install offers --group" true (contains -- --group $got; and echo true; or echo false)

# auto-pull remove reads the registry from the user-dots directory, so it
# needs the repo functions (for __fish_user_dots_dir) and must honor a
# custom __fish_user_dots_path.
set -l tmp (mktemp -d)
printf '%s\n' /src/ud-probe-repo >$tmp/auto-pull.list
set -l got (env TERM=dumb fish --no-config -c \
    "set -g fish_function_path $repo_root/functions \$fish_function_path
    set fish_complete_path $repo_root/completions \$fish_complete_path
    set -g __fish_user_dots_path $tmp
    function auto-pull; end
    complete -C 'auto-pull remove '" | string split -f1 \t)
check "auto-pull remove <Tab> reads a custom user-dots path" true (contains -- ud-probe-repo $got; and echo true; or echo false)
rm -rf $tmp

set -l got (_offered 'fish-deps install --')
check "fish-deps install offers --optional" true (contains -- --optional $got; and echo true; or echo false)
set -l got (_offered 'fish-deps update --')
check "fish-deps update hides --optional" false (contains -- --optional $got; and echo true; or echo false)
set -l got (_offered 'fish-deps install ')
check "fish-deps install <Tab> offers catalog tools" true (contains -- fzf $got; and echo true; or echo false)

set -l got (_offered 'superpowers -g -')
check "superpowers hides -g once given" false (contains -- -g $got; and echo true; or echo false)

set -l got (_offered 'pkg -u -')
check "pkg -u hides -i" false (contains -- -i $got; and echo true; or echo false)

set -l got (_offered 'split -')
check "split offers --vertical first" true (contains -- --vertical $got; and echo true; or echo false)
set -l got (_offered 'split -v -')
check "split -v hides --vertical" false (contains -- --vertical $got; and echo true; or echo false)

# The command-running wrappers complete a command name in the first slot.
for fn in bkg wake-lock detach split
    set -l got (_offered "$fn fis")
    check "$fn fis<Tab> offers fish" true (contains -- fish $got; and echo true; or echo false)
end

# Past the command's name, the command's own completions take over.
set -l got (_offered 'detach split -')
check "detach split -<Tab> offers split's --vertical" true (contains -- --vertical $got; and echo true; or echo false)

set -l got (_offered 'sbver --brief -')
check "sbver takes one flag at most" false (contains -- --brief $got; and echo true; or echo false)

set -l got (_offered 'rm --e')
check "rm offers --empty" true (contains -- --empty $got; and echo true; or echo false)
set -l got (_offered 'rm -r --e')
check "rm offers --empty only first" false (contains -- --empty $got; and echo true; or echo false)
set -l got (_offered 'du --d')
check "du offers --disk" true (contains -- --disk $got; and echo true; or echo false)
set -l got (_offered 'md --')
check "md offers --read-only" true (contains -- --read-only $got; and echo true; or echo false)

# config-help reads the manual index under $__fish_config_dir, which fish
# derives from XDG_CONFIG_HOME (and keeps read-only).
set -l tmp (mktemp -d)
ln -s $repo_root $tmp/fish
set -l got (env TERM=dumb XDG_CONFIG_HOME=$tmp fish --no-config -c \
    "set fish_complete_path $repo_root/completions \$fish_complete_path
    function config-help; end
    complete -C 'config-help keyb'" | string split -f1 \t)
check "config-help keyb<Tab> offers keybindings" true (contains -- keybindings $got; and echo true; or echo false)
rm -rf $tmp

# __fish_source_upstream_completion loads the next <cmd>.fish on the path,
# not the calling file itself (which would recurse).
set -l tmp (mktemp -d)
mkdir -p $tmp/ours $tmp/upstream
printf '%s\n' 'complete -c probe -l from-upstream' >$tmp/upstream/probe.fish
printf '%s\n' '__fish_source_upstream_completion probe (status filename)' \
    'complete -c probe -l from-ours' >$tmp/ours/probe.fish
set -l got (env TERM=dumb fish --no-config -c \
    "set -g fish_function_path $repo_root/functions \$fish_function_path
    set fish_complete_path $tmp/ours $tmp/upstream
    function probe; end
    complete -C 'probe --'" | string split -f1 \t)
check "upstream helper loads the upstream file" true (contains -- --from-upstream $got; and echo true; or echo false)
check "upstream helper keeps the caller's own" true (contains -- --from-ours $got; and echo true; or echo false)
rm -rf $tmp

report
