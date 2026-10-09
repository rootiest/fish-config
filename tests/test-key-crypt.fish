#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# functions/key-crypt.fish (OpenPGP encrypt/decrypt of a file or directory) and
# its completion file. Issue #238.
#
# SAFETY. key-crypt is a crypto helper that, by default, reaches for the
# connected smartcard. Nothing here may touch the real keyring, gpg-agent,
# scdaemon/YubiKey or $HOME:
#
#   * GNUPGHOME is a throwaway mode-700 dir under mktemp with a short path
#     (agent socket paths have a length limit). Its gpg-agent.conf sets
#     `disable-scdaemon` (the card is unreachable even if a token is plugged
#     in), `pinentry-program /bin/false` (a prompt can only fail, never
#     appear) and `allow-loopback-pinentry`.
#   * The test key is generated inside it with an empty passphrase.
#   * HOME is a throwaway dir, so --install/--uninstall cannot reach the real
#     ~/.local; the real paths are snapshotted before and after to prove it.
#   * Every key-crypt call runs in its own `timeout` -wrapped --no-config fish
#     with stdin from /dev/null, so a hung agent stalls one call (and fails
#     it), never the suite, and nothing can wait on a prompt.
#   * Every call passes --key explicitly where card detection would otherwise
#     run; the one test that omits it is safe because the card is disabled.
#   * The sandbox agent is killed (gpgconf --kill all) before exit.
#
# Without gpg, tar or timeout the key-bearing sections SKIP with a message;
# the help, usage, install/uninstall and completion sections need none of them.

source (realpath (dirname (status filename)))/lib.fish

set -g fn_file (realpath $repo_root/functions/key-crypt.fish)
set -g sb (mktemp -d)
or begin
    echo "  FAIL  cannot create sandbox"
    exit 1
end
set -g real_home $HOME

# A single run: exit status in $kc_rc, stdout in $kc_out, stderr in $kc_err.
# Own fish per call so the function's globals never leak between cases and a
# wedged gpg is bounded by `timeout`.
function kc
    timeout -k 5 60 fish --no-config -c 'source $argv[1]; key-crypt $argv[2..-1]' \
        $fn_file $argv </dev/null >$sb/out 2>$sb/err
    set -g kc_rc $status
    set -g kc_out (string collect <$sb/out)
    set -g kc_err (string collect <$sb/err)
end

# Same, but under the second (decoy) keyring.
function kc_other
    set -lx GNUPGHOME $sb/g2
    kc $argv
end

function b
    # Boolean from a predicate: b test -e foo
    $argv
    and echo true
    or echo false
end

function has --argument-names needle haystack
    string match -q -- "*$needle*" "$haystack"
    and echo true
    or echo false
end

# Exported state for every child process.
set -gx HOME $sb/home
set -gx GNUPGHOME $sb/g
set -gx GPG_TTY ''
set -gx TERM dumb
set -gx NO_COLOR 1
mkdir -p $HOME
mkdir -m 700 $GNUPGHOME $sb/g2

# What the real HOME holds that key-crypt --install would create.
function real_snapshot
    find $real_home/.local/bin $real_home/.local/share/applications \
        -maxdepth 1 -name 'key-crypt*' -printf '%p %T@ %s\n' 2>/dev/null | sort
end
set -l real_before (real_snapshot | string collect)

# ---- Section: help ----------------------------------------------------------
section "key-crypt --help"

for flag in --help -h
    kc $flag
    check "$flag: exits 0" 0 $kc_rc
    check "$flag: prints Usage on stdout" true (has "Usage: key-crypt" "$kc_out")
    check "$flag: documents --install" true (has --install "$kc_out")
    check "$flag: documents exit status 2" true (has "Bad usage" "$kc_out")
    check "$flag: nothing on stderr" "" "$kc_err"
end

# ---- Section: usage errors ---------------------------------------------------
section "key-crypt usage errors exit 2"

kc
check "no arguments: exit 2" 2 $kc_rc
check "no arguments: usage goes to stderr" true (has "Usage: key-crypt" "$kc_err")
check "no arguments: stdout empty" "" "$kc_out"

kc --bogus
check "unknown flag: exit 2" 2 $kc_rc
check "unknown flag: stdout empty" "" "$kc_out"

kc a b c
check "three positionals: exit 2" 2 $kc_rc

kc -i a b c
check "--input plus two positionals: exit 2" 2 $kc_rc
check "--input plus two positionals: says too many" true (has "too many arguments" "$kc_err")

kc -i a -o b c
check "output given twice: exit 2" 2 $kc_rc
check "output given twice: says so" true (has "output given twice" "$kc_err")

kc a b -o c
check "positional output plus --output: exit 2" 2 $kc_rc

kc -k
check "--key without a value: exit 2" 2 $kc_rc

kc --install --force
check "--install with another flag: exit 2" 2 $kc_rc
check "--install with another flag: explains" true (has "cannot be combined" "$kc_err")

kc --uninstall foo
check "--uninstall with an argument: exit 2" 2 $kc_rc

kc --install --uninstall
check "--install --uninstall together: exit 2" 2 $kc_rc

kc --install --help
check "--install --help: help wins, exit 0" 0 $kc_rc
check "--install --help: prints usage" true (has "Usage: key-crypt" "$kc_out")
check "--install --help: installs nothing" false (b test -e $HOME/.local/bin/key-crypt)

kc $sb/definitely-missing
check "missing input: exit 1" 1 $kc_rc
check "missing input: says input not found" true (has "input not found" "$kc_err")

# ---- Section: install / uninstall -------------------------------------------
section "key-crypt --install / --uninstall (sandboxed HOME)"

set -l app $HOME/.local/share/applications
set -l bin $HOME/.local/bin/key-crypt

kc --uninstall
check "uninstall when absent: exit 0" 0 $kc_rc
check "uninstall when absent: says nothing to remove" true (has "nothing to remove" "$kc_err")

kc --install
check "install: exit 0" 0 $kc_rc
check "install: stdout empty" "" "$kc_out"
check "install: wrapper written in sandbox HOME" true (b test -f $bin)
check "install: wrapper is executable" true (b test -x $bin)
check "install: Key-Crypt entry written" true (b test -f $app/key-crypt.desktop)
check "install: preset entry written" true (b test -f $app/key-crypt-preset.desktop)
check "install: entry has its name" true (has "Name=Key-Crypt" (string collect <$app/key-crypt.desktop))
check "install: preset entry passes --preset" true (has "--preset" (string collect <$app/key-crypt-preset.desktop))
check "install: entry execs the sandbox wrapper" true (has "$bin" (string collect <$app/key-crypt.desktop))
check "install: wrapper sources this repo's function" true (has "source "(string escape -- $fn_file) (string collect <$bin))

# The generated wrapper must really run standalone (that is the whole point).
set -l wrapper_out (timeout -k 5 30 $bin --help </dev/null 2>&1 | string collect)
check "installed wrapper runs and shows help" true (has "Usage: key-crypt" "$wrapper_out")
timeout -k 5 30 $bin a b c </dev/null >/dev/null 2>&1
check "installed wrapper propagates exit status 2" 2 $status

echo keepme >$app/unrelated.desktop
kc --install
check "re-install is idempotent: exit 0" 0 $kc_rc

kc --uninstall
# __kc_uninstall ends on `command -q update-desktop-database; and ...`, so on a
# host without that tool a successful uninstall reports 1 (reported on #238,
# not asserted here). Pin the exit status only where the tool exists.
if type -q update-desktop-database
    check "uninstall: exit 0" 0 $kc_rc
else
    echo "  SKIP  update-desktop-database not installed: uninstall exit status not asserted"
end
check "uninstall: wrapper removed" false (b test -e $bin)
check "uninstall: entry removed" false (b test -e $app/key-crypt.desktop)
check "uninstall: preset entry removed" false (b test -e $app/key-crypt-preset.desktop)
check "uninstall: unrelated files untouched" true (b test -f $app/unrelated.desktop)

# A HOME that is unsafe inside a quoted .desktop Exec line is refused before
# anything is written.
set -l odd "$sb/odd home"
mkdir -p $odd
begin
    set -lx HOME $odd
    kc --install
end
check "unsafe install path: exit 1" 1 $kc_rc
check "unsafe install path: says why" true (has "unsafe" "$kc_err")
check "unsafe install path: nothing written" 0 (find $odd -mindepth 1 | count)

check "real ~/.local key-crypt files unchanged" "$real_before" (real_snapshot | string collect)

# ---- Section: completions ----------------------------------------------------
section "key-crypt completions cover every accepted flag"

# `key-crypt --` only: the -k value generator would query gpg, so it is not
# invoked here (and GNUPGHOME is the sandbox anyway).
set -l offered (env TERM=dumb fish --no-config -c \
    "set fish_complete_path $repo_root/completions \$fish_complete_path; function key-crypt; end; complete -C 'key-crypt --'" \
    </dev/null | string split -f1 \t)
# --extract is a deliberate silent no-op and not advertised.
for flag in --help --input --output --key --force --archive --mkdir --preset --remove --install --uninstall
    check "completion offers $flag" true (b contains -- $flag $offered)
end
check "completion does not advertise --extract" false (b contains -- --extract $offered)
# The function really does still accept the hidden flag.
set -l argparse_spec (string match -r "argparse -n \\\$prog.*" <$fn_file)
check "function still parses -e/--extract" true (has "e/extract" "$argparse_spec")

# ---- Section: gpg-backed behaviour -------------------------------------------
if not type -q gpg; or not type -q tar; or not type -q timeout
    echo ""
    echo "  SKIP  gpg, tar or timeout not installed: round-trip and failure-path cases not run"
else
    # Agent config first: no card, no prompts, loopback allowed.
    printf '%s\n' disable-scdaemon allow-loopback-pinentry 'pinentry-program /bin/false' >$sb/g/gpg-agent.conf
    command cp -f $sb/g/gpg-agent.conf $sb/g2/gpg-agent.conf

    function mkkey --argument-names home uid
        set -lx GNUPGHOME $home
        timeout -k 5 60 gpg --batch --pinentry-mode loopback --passphrase '' \
            --quick-generate-key "$uid" ed25519 sign never </dev/null >/dev/null 2>&1
        or return 1
        set -l f (timeout -k 5 30 gpg --batch --list-keys --with-colons </dev/null 2>/dev/null \
            | string replace -rf '^fpr:::::::::([0-9A-F]+):.*' '$1' | head -n 1)
        test -n "$f"; or return 1
        timeout -k 5 60 gpg --batch --pinentry-mode loopback --passphrase '' \
            --quick-add-key $f cv25519 encr never </dev/null >/dev/null 2>&1
        or return 1
        echo $f
    end

    set -l fpr (mkkey $sb/g 'kc-test <kc@example.invalid>')
    set -l fpr2 (mkkey $sb/g2 'kc-decoy <decoy@example.invalid>')

    if test -z "$fpr"; or test -z "$fpr2"
        echo ""
        echo "  SKIP  could not generate a throwaway OpenPGP key (gpg-agent unusable here)"
    else
        set -l work $sb/work
        mkdir -p $work
        cd $work

        set -l secret SECRET-PLAINTEXT-5f3a9c
        printf '%s\n' $secret second-line >note.txt

        # ---- file round trip ----
        section "key-crypt file round trip"

        kc -k $fpr note.txt
        check "encrypt file: exit 0" 0 $kc_rc
        check "encrypt file: default output is <file>.gpg" true (b test -f note.txt.gpg)
        check "encrypt file: input kept" true (b test -f note.txt)
        check "encrypt file: stdout empty" "" "$kc_out"
        check "encrypt file: stderr reports the output name" true (has "wrote note.txt.gpg" "$kc_err")
        check "encrypt file: ciphertext does not contain the plaintext" false (b grep -qa -- $secret note.txt.gpg)
        check "encrypt file: output is OpenPGP-encrypted" true (gpg --batch --list-only --list-packets note.txt.gpg </dev/null 2>/dev/null | string match -rq '^:pubkey enc packet:'; and echo true; or echo false)
        check "encrypt file: no temp files left" "note.txt note.txt.gpg" (command ls $work | string join " ")

        kc -k $fpr note.txt.gpg restored.txt
        check "decrypt file: exit 0" 0 $kc_rc
        check "decrypt file: stdout empty" "" "$kc_out"
        check "decrypt file: plaintext restored byte for byte" true (b cmp -s note.txt restored.txt)
        check "decrypt file: encrypted input kept" true (b test -f note.txt.gpg)
        check "decrypt file: no temp files left" "note.txt note.txt.gpg restored.txt" (command ls $work | string join " ")

        # Secrets never leak to stdout or stderr on any success path.
        check "round trip: plaintext never printed (stdout)" false (has $secret "$kc_out")
        check "round trip: plaintext never printed (stderr)" false (has $secret "$kc_err")

        kc -k $fpr note.txt.gpg
        check "decrypt onto existing default output: exit 1" 1 $kc_rc
        check "decrypt onto existing default output: says output exists" true (has "output exists" "$kc_err")
        check "existing output untouched without --force" true (b cmp -s note.txt restored.txt)

        printf 'stale\n' >stale.txt
        kc -k $fpr note.txt.gpg stale.txt
        check "decrypt onto existing file: exit 1 without --force" 1 $kc_rc
        check "decrypt onto existing file: content preserved" stale (string collect <stale.txt | string trim)
        kc -f -k $fpr note.txt.gpg stale.txt
        check "decrypt onto existing file: --force exit 0" 0 $kc_rc
        check "decrypt onto existing file: --force overwrote it" true (b cmp -s note.txt stale.txt)

        kc -k $fpr -i note.txt -o explicit.gpg
        check "explicit --input/--output: exit 0" 0 $kc_rc
        check "explicit --input/--output: wrote the named file" true (b test -f explicit.gpg)

        kc -k $fpr note.txt note.txt
        check "encrypt output same as input: exit 1" 1 $kc_rc
        check "encrypt output same as input: says so" true (has "same as input" "$kc_err")

        # ---- directory round trip ----
        section "key-crypt directory round trip"

        mkdir -p proj/sub/deep
        printf '%s\n' $secret >proj/a.txt
        printf 'beta\n' >proj/sub/b.txt
        printf 'gamma\n' >proj/sub/deep/c.txt

        kc -k $fpr proj
        check "encrypt dir: exit 0" 0 $kc_rc
        check "encrypt dir: default output is <dir>.tgz.gpg" true (b test -f proj.tgz.gpg)
        check "encrypt dir: ciphertext does not contain file contents" false (b grep -qa -- $secret proj.tgz.gpg)

        kc -f -k $fpr proj/
        check "encrypt dir: trailing slash on input accepted" 0 $kc_rc

        kc -m -k $fpr proj.tgz.gpg restored
        check "decrypt dir: exit 0" 0 $kc_rc
        check "decrypt dir: tree restored identically" true (b diff -r proj restored)
        check "decrypt dir: no stray temp files" "" (command ls -A $work | string match -r '\.[A-Za-z0-9]{6}$')

        kc -m -k $fpr proj.tgz.gpg nested/new/dir
        check "decrypt dir: --mkdir creates missing parents" true (b diff -r proj nested/new/dir)

        kc -k $fpr proj.tgz.gpg nomkdir
        check "decrypt dir to missing output without --mkdir (non-tty): exit 1" 1 $kc_rc
        check "decrypt dir to missing output: points at --mkdir" true (has --mkdir "$kc_err")
        check "decrypt dir to missing output: nothing extracted" false (b test -e nomkdir)
        check "decrypt dir to missing output: no plaintext temp left" "" (command ls -A $work | string match -r '^nomkdir')

        kc -k $fpr proj.tgz.gpg restored
        check "decrypt dir onto non-empty dir: exit 1" 1 $kc_rc
        check "decrypt dir onto non-empty dir: says output exists" true (has "output exists" "$kc_err")

        kc -a -k $fpr proj.tgz.gpg
        check "decrypt --archive: exit 0" 0 $kc_rc
        check "decrypt --archive: archive kept as <name>.tgz" true (b test -f proj.tgz)
        check "decrypt --archive: result is a readable tar" true (tar -tzf proj.tgz >/dev/null 2>&1; and echo true; or echo false)

        # tar failing mid-pipeline (unreadable file) must fail the encrypt: no
        # truncated archive may be passed off as a good ciphertext. root can
        # read anything, so the case needs an unprivileged user.
        if test (id -u) -ne 0
            mkdir -p unreadable_dir
            printf 'x\n' >unreadable_dir/secret
            chmod 000 unreadable_dir/secret
            kc -k $fpr unreadable_dir
            check "encrypt dir with an unreadable file: exit 1" 1 $kc_rc
            check "encrypt dir with an unreadable file: no output file" false (b test -e unreadable_dir.tgz.gpg)
            chmod 600 unreadable_dir/secret
        else
            echo "  SKIP  encrypt dir with an unreadable file (running as root)"
        end

        kc -a -k $fpr proj.tgz.gpg arch/
        check "--archive with trailing-slash output: exit 1" 1 $kc_rc
        check "--archive with trailing-slash output: says conflict" true (has "conflicts" "$kc_err")

        kc -k $fpr note.txt.gpg onlydir/
        check "trailing slash on a non-tar payload: exit 1" 1 $kc_rc
        check "trailing slash on a non-tar payload: says not a tar archive" true (has "not a tar archive" "$kc_err")
        check "trailing slash on a non-tar payload: nothing written" false (b test -e onlydir)

        # ---- --remove / --preset ----
        section "key-crypt --remove and --preset"

        mkdir rm1
        printf 'x\n' >rm1/f
        kc -r -k $fpr rm1
        check "--remove encrypt dir: exit 0" 0 $kc_rc
        check "--remove encrypt dir: encrypted output exists" true (b test -f rm1.tgz.gpg)
        check "--remove encrypt dir: original removed" false (b test -e rm1)
        kc -r -m -k $fpr rm1.tgz.gpg
        check "--remove decrypt: exit 0" 0 $kc_rc
        check "--remove decrypt: plaintext restored" x (string collect <rm1/f | string trim)
        check "--remove decrypt: encrypted input removed" false (b test -e rm1.tgz.gpg)

        mkdir rm2
        kc -r -k $fpr rm2 rm2/inside.tgz.gpg
        check "--remove with output inside input: refused, exit 1" 1 $kc_rc
        check "--remove with output inside input: says refusing" true (has "refusing --remove" "$kc_err")
        check "--remove with output inside input: input kept" true (b test -d rm2)

        printf 'p\n' >pre.txt
        kc -k $fpr pre.txt
        command rm -f pre.txt
        printf 'old\n' >pre.txt
        kc -p -k $fpr pre.txt.gpg
        check "--preset decrypt over existing output: exit 0" 0 $kc_rc
        check "--preset decrypt: overwrote existing output" p (string collect <pre.txt | string trim)
        check "--preset decrypt: removed the input" false (b test -e pre.txt.gpg)

        # ---- failure paths ----
        section "key-crypt failure paths leave no partial output"

        set -l before (command ls -A $work | string join " ")
        kc -k 0000000000000000000000000000000000000BAD note.txt nokey.gpg
        check "encrypt to an unknown key: exit 1" 1 $kc_rc
        check "encrypt to an unknown key: no output written" false (b test -e nokey.gpg)
        check "encrypt to an unknown key: no temp files left" "$before" (command ls -A $work | string join " ")

        # Wrong key: the decoy keyring holds no secret key for this file.
        set -l before (command ls -A $work | string join " ")
        kc_other -k $fpr2 note.txt.gpg wrongkey.txt
        check "decrypt with the wrong keyring: exit 1" 1 $kc_rc
        check "decrypt with the wrong keyring: no output written" false (b test -e wrongkey.txt)
        check "decrypt with the wrong keyring: no temp files left" "$before" (command ls -A $work | string join " ")
        check "decrypt with the wrong keyring: no plaintext on stdout" "" "$kc_out"
        check "decrypt with the wrong keyring: no plaintext on stderr" false (has $secret "$kc_err")

        kc_other -k $fpr2 -r note.txt.gpg wrongkey.txt
        check "wrong key with --remove: exit 1" 1 $kc_rc
        check "wrong key with --remove: encrypted input kept" true (b test -f note.txt.gpg)

        # Corrupted: flip one byte near the end (inside the MDC-protected body),
        # and separately truncate the tail.
        set -l size (stat -c %s note.txt.gpg)
        command cp -f note.txt.gpg corrupt.gpg
        printf '\377' | dd of=corrupt.gpg bs=1 seek=(math $size - 5) conv=notrunc 2>/dev/null
        command cp -f note.txt.gpg trunc.gpg
        truncate -s (math $size - 12) trunc.gpg
        set -l before (command ls -A $work | string join " ")
        for bad in corrupt.gpg trunc.gpg
            kc -k $fpr $bad "out-$bad.txt"
            check "$bad: exit 1" 1 $kc_rc
            check "$bad: no output written" false (b test -e "out-$bad.txt")
            check "$bad: no plaintext on stdout" "" "$kc_out"
            check "$bad: no plaintext leaked to stderr" false (has $secret "$kc_err")
            check "$bad: no temp files left" "$before" (command ls -A $work | string join " ")
            kc -r -k $fpr $bad "out-$bad.txt"
            check "$bad with --remove: exit 1" 1 $kc_rc
            check "$bad with --remove: corrupt input kept" true (b test -f $bad)
        end

        # With no --key and no card, a non-interactive run cannot ask: it must
        # fail cleanly rather than hang or guess. (The sandbox agent has the
        # card disabled, so detection finds nothing.)
        kc note.txt nokey2.gpg
        check "no --key, no card, no tty: exit 1" 1 $kc_rc
        check "no --key, no card, no tty: tells you to pass --key" true (has --key "$kc_err")
        check "no --key, no card, no tty: nothing written" false (b test -e nokey2.gpg)
        kc note.txt.gpg nokey3.txt
        check "decrypt with no --key, no card, no tty: exit 1" 1 $kc_rc
        check "decrypt with no --key, no card, no tty: nothing written" false (b test -e nokey3.txt)
        check "decrypt with no --key, no card, no tty: no plaintext leaked" false (has $secret "$kc_err$kc_out")

        # A non-GPG file is simply encrypted, never decrypted; exit 0 and a .gpg.
        printf 'not encrypted\n' >plain.bin
        kc -k $fpr plain.bin
        check "non-gpg input is encrypted, not rejected" 0 $kc_rc
        check "non-gpg input: .gpg produced" true (b test -f plain.bin.gpg)

        cd $sb
    end

    # Always stop the sandbox agents so nothing outlives the suite.
    for home in $sb/g $sb/g2
        env GNUPGHOME=$home timeout -k 2 10 gpgconf --kill all </dev/null >/dev/null 2>&1
    end
end

cd /
command rm -rf $sb
report
