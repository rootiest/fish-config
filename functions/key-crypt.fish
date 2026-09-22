# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   13-media-and-utilities
#
# DEPENDENCIES
#   gpg, tar
#
# CLASSIFICATION
#   bypasses-shadow(rm), destructive
#
# SYNOPSIS
#   key-crypt [options] <input> [output]
#   key-crypt -i <input> -o <output> [options]
#   key-crypt --install | --uninstall
#
# DESCRIPTION
#   Encrypts or decrypts a file or directory with OpenPGP, choosing the
#   recipient/secret key from the connected smartcard (YubiKey etc.) by
#   default. Direction is detected from the input: a GPG-encrypted file is
#   decrypted (a tar payload is extracted into the output directory),
#   anything else is encrypted. Run with --help for the full reference,
#   including key selection and output-naming rules.
#
# ARGUMENTS
#   -i, --input PATH    Directory, file, or encrypted file to process
#   -o, --output PATH   Where to write the result
#   -k, --key KEY       Key ID or fingerprint (repeatable); overrides card detection
#   -f, --force         Overwrite an existing output
#   -a, --archive       Decrypt: keep the decrypted archive as-is instead of extracting
#   -m, --mkdir         Decrypt: create the output directory without asking
#   -p, --preset        Hands-off mode: same as --force --mkdir --remove
#   -r, --remove        Delete the input after a successful run
#       --install       Copy a standalone wrapper to ~/.local/bin and add
#                       "Open With" entries for .gpg files and folders.
#                       Must be the only argument.
#       --uninstall     Remove the installed wrapper and entries. Same rule.
#   -h, --help          Show this help message
#
# EXIT STATUS
#   0  Success
#   1  Error (missing input, output exists, gpg or tar failed, no key)
#   2  Bad usage
#
# EXAMPLE
#   key-crypt mydir                  # -> mydir.tgz.gpg
#   key-crypt mydir.tgz.gpg          # -> extracted into mydir/
#   key-crypt -k 0xDEADBEEF mydir    # choose the recipient manually
#   key-crypt --install              # register the standalone wrapper + Open With entries
#
# NOTES
#   --remove uses plain rm, not a secure wipe: on SSDs and copy-on-write
#   filesystems the old data may remain recoverable. The input is only
#   removed after the output is fully written; when decrypting, that means
#   the encrypted file is deleted only once gpg has verified and decrypted it.

function __kc_die
    printf '%s: %s\n' $prog "$argv" >&2
    return 1
end

function __kc_warn
    printf '%s: %s\n' $prog "$argv" >&2
end

# Sets c_head/c_name/c_flag/c_arg/c_dim/c_reset. Defaults are named colors by
# role like fish's highlighter (command=blue, option=green, param=cyan,
# muted=brblack); the user's fish theme overrides them when it can be found.
function __kc_colors
    set -g c_head ''
    set -g c_name ''
    set -g c_flag ''
    set -g c_arg ''
    set -g c_dim ''
    set -g c_reset ''
    isatty stdout; or return 0
    test -z "$NO_COLOR"; or return 0

    set -g c_head (set_color --bold yellow)
    set -g c_name (set_color brblue)
    set -g c_flag (set_color brgreen)
    set -g c_arg (set_color cyan)
    set -g c_dim (set_color brblack)
    set -g c_reset (set_color normal)

    # Prints "role=escape" per theme variable. A normal interactive shell
    # already has these as globals; --no-config runs (the installed
    # wrapper) do not, so ask an interactive fish once in that case.
    set -l snippet 'for r in command option param autosuggestion
    set -l v fish_color_$r
    set -q $v; or continue
    test (count $$v) -gt 0; or continue
    printf "%s=" $r; set_color $$v; printf "\n"
end'
    set -l lines
    if set -q fish_color_command
        set lines (eval $snippet)
    else if command -q fish; and command -q timeout
        set lines (timeout 2 fish -ic $snippet </dev/null 2>/dev/null)
    end
    for l in $lines
        set -l m (string match -r '^(command|option|param|autosuggestion)=(.*)$' -- $l)
        test (count $m) -eq 3; or continue
        string match -qr '^(\x1b\[[0-9;:]*m)+$' -- $m[3]; or continue
        switch $m[2]
            case command
                set -g c_name $m[3]
            case option
                set -g c_flag $m[3]
            case param
                set -g c_arg $m[3]
            case autosuggestion
                set -g c_dim $m[3]
        end
    end
end

# The help text is a template: {h} header, {c} command, {f} flag, {a} value,
# {d} muted, {/} reset, {P} the name this was invoked as.
function __kc_usage
    __kc_colors
    set -l t '{h}Usage:{/} {c}{P}{/} {f}[options]{/} {d}<input> [output]{/}
       {c}{P}{/} {f}-i{/} {d}<input>{/} {f}-o{/} {d}<output>{/} {f}[options]{/}
       {c}{P}{/} {f}--install{/} | {f}--uninstall{/}

Encrypt or decrypt a file or directory with OpenPGP. The direction is detected
from the input: an encrypted file is decrypted, anything else is encrypted.

{h}Options:{/}
  {f}-i{/}, {f}--input{/} {d}PATH{/}    Directory, file, or encrypted file to process
  {f}-o{/}, {f}--output{/} {d}PATH{/}   Where to write the result (see {h}Output{/})
  {f}-k{/}, {f}--key{/} {d}KEY{/}       Key ID or fingerprint. Encrypt: recipient (repeatable).
                        Decrypt: secret key to try. Overrides card detection.
  {f}-f{/}, {f}--force{/}         Overwrite an existing output
  {f}-a{/}, {f}--archive{/}       Decrypt: keep the decrypted archive as-is instead of
                        extracting it
  {f}-m{/}, {f}--mkdir{/}         Decrypt: create the output directory without asking
  {f}-p{/}, {f}--preset{/}        Hands-off mode: same as {f}--force --mkdir --remove{/}
  {f}-r{/}, {f}--remove{/}        Delete the input after it was encrypted/decrypted successfully
      {f}--install{/}       Copy a standalone wrapper to ~/.local/bin/{c}key-crypt{/} and add
                        two Open With entries for .gpg files and folders:
                        Key-Crypt and "Key-Crypt (Remove Original)" (runs {f}--preset{/}).
                        Must be the only option; nothing else may be given.
      {f}--uninstall{/}     Remove the installed wrapper and both entries.
                        Same rule: must be the only option.
  {f}-h{/}, {f}--help{/}          Show this help message

  A bare argument is the input, or the output when {f}--input{/} is given.

{h}Key selection:{/}
  Encrypt  Uses the encryption subkey of the connected OpenPGP card. If no card
           is found, or its key is not in your keyring, you are prompted.
  Decrypt  Checks that the file is addressed to the connected card. If not, the
           recipients are listed and you are prompted for the key to use
           (blank lets gpg choose). The card needs its PIN, and touch if enabled.

{h}Output:{/}
  Encrypt  A directory is packed as tar+gzip. Default output:
             directory  ->  <dir>.tgz.gpg
             file       ->  <file>.gpg
  Decrypt  Default output is the input without .gpg/.pgp/.asc. A tar payload is
           extracted into a directory named after the archive, minus its
           extension (mydir.tgz.gpg -> mydir/). Any other payload is written
           as a file (photo.jpg.gpg -> photo.jpg).
           With {f}--archive{/} the decrypted archive is kept as-is
           (mydir.tgz.gpg -> mydir.tgz).
           A trailing slash on the output requires a tar payload; anything else
           fails.
           A missing output directory is created after a [Y/n] prompt (asked
           once decryption succeeds), or straight away with {f}--mkdir{/}.

{h}Examples:{/}
  {c}{P}{/} {a}mydir{/}                          {d}# -> mydir.tgz.gpg{/}
  {c}{P}{/} {f}--input{/} {a}mydir{/} {a}mydir.tgz.gpg{/}    {d}# explicit output{/}
  {c}{P}{/} {f}-i{/} {a}mydir{/} {f}-o{/} {a}backup.tgz.gpg{/}
  {c}{P}{/} {a}mydir.tgz.gpg{/}                  {d}# extracted into mydir/{/}
  {c}{P}{/} {a}mydir.tgz.gpg{/} {a}restored{/}         {d}# extracted into restored/{/}
  {c}{P}{/} {f}-a{/} {a}mydir.tgz.gpg{/}               {d}# -> mydir.tgz (archive kept){/}
  {c}{P}{/} {f}-m{/} {a}mydir.tgz.gpg{/} {a}a/b/restored{/}  {d}# create a/b/restored without asking{/}
  {c}{P}{/} {f}-k{/} {a}0xDEADBEEF{/} {a}mydir{/}            {d}# choose the recipient manually{/}
  {c}{P}{/} {f}--remove{/} {a}mydir{/}                 {d}# encrypt, then delete mydir{/}
  {c}{P}{/} {f}-p{/} {a}mydir.tgz.gpg{/}               {d}# decrypt into mydir/, delete the .gpg{/}
  {c}{P}{/} {f}-r{/} {a}mydir.tgz.gpg{/} {a}restored{/}      {d}# decrypt, then delete mydir.tgz.gpg{/}

{h}Exit status:{/}
  {f}0{/}  Success
  {f}1{/}  Error (missing input, output exists, gpg or tar failed, no key)
  {f}2{/}  Bad usage

{h}Notes:{/}
  {f}--remove{/} uses plain {f}rm{/}, not a secure wipe: on SSDs and copy-on-write
  filesystems the old data may remain recoverable. The input is only removed
  after the output is fully written; when decrypting, that means the encrypted
  file is deleted only once gpg has verified and decrypted it.'
    printf '%s\n' "$t" \
        | string replace -a '{h}' "$c_head" \
        | string replace -a '{c}' "$c_name" \
        | string replace -a '{f}' "$c_flag" \
        | string replace -a '{a}' "$c_arg" \
        | string replace -a '{d}' "$c_dim" \
        | string replace -a '{/}' "$c_reset" \
        | string replace -a '{P}' $prog
end

# Sets card_enc to the card's encryption subkey fingerprint (empty if no card).
function __kc_detect_card
    set -g card_enc ''
    set -l f (gpg --card-status --with-colons 2>/dev/null | string replace -rf '^fpr:[^:]*:([0-9A-Fa-f]+):.*' '$1' | head -n 1)
    string match -qr '^0*$' -- "$f"; or set -g card_enc $f
end

# Asks for a key; sets key_answer (empty if the user just presses Enter).
# Prompts read with head, not fish's read: read starts the full line editor,
# which queries the terminal and can swallow the first keystrokes.
function __kc_ask_key
    isatty stdin; and isatty stderr; or __kc_die "$argv[1] -- pass a key with --key"; or return 1
    __kc_warn $argv[1]
    printf 'Key ID or fingerprint: ' >&2
    set -g key_answer (head -n 1)
end

# --list-only: dump packets without trying to decrypt (no PIN/touch, and no
# failure when the secret key is absent).
function __kc_packets
    gpg --batch --list-only --list-packets -- $argv[1] 2>/dev/null
end

function __kc_is_encrypted
    test -f $argv[1]; or return 1
    __kc_packets $argv[1] | string match -rq '^:(pubkey|symkey) enc packet:'
end

function __kc_check_output
    test -e $output; or return 0
    test $force -eq 1; and return 0
    test -d $output; and test -z "$(command ls -A -- $output)"; and return 0
    __kc_die "output exists: $output (use --force to overwrite)"
end

function __kc_encrypt
    if test (count $keys) -eq 0
        __kc_detect_card
        set -g key_answer ''
        if test -z "$card_enc"
            __kc_ask_key "no OpenPGP card detected"; or return 1
        else if not gpg --batch --list-keys -- $card_enc >/dev/null 2>&1
            __kc_ask_key "card key "(string sub -s -16 -- $card_enc)" is not in your keyring (import it: gpg --card-edit, then fetch)"; or return 1
        else
            set -g keys "$card_enc!"
            __kc_warn "encrypting to card key "(string sub -s -16 -- $card_enc)
        end
        if test (count $keys) -eq 0
            test -n "$key_answer"; or __kc_die "no key given"; or return 1
            set -g keys $key_answer
        end
    end

    if test -z "$output"
        if test -d $input
            set -g output $input.tgz.gpg
        else
            set -g output $input.gpg
        end
    end
    test "$output" != "$input"; or __kc_die "output is the same as input"; or return 1
    if test $remove -eq 1; and test -d $input
        set -l ri (realpath -- $input)
        set -l ro (realpath -m -- $output)
        if test (string sub -l (math (string length -- $ri) + 1) -- "$ro/") = "$ri/"
            __kc_die "refusing --remove: output $output is inside $input"; or return 1
        end
    end
    __kc_check_output; or return 1

    set -l rcpt
    for k in $keys
        set -a rcpt -r $k
    end

    set -g tmp (mktemp -- "$output.XXXXXX"); or __kc_die "cannot create a temp file next to $output"; or return 1
    if test -d $input
        tar -czf - -C $input . | gpg --yes $rcpt -o $tmp --encrypt
        set -l st $pipestatus
        test $st[1] -eq 0; and test $st[2] -eq 0; or return 1
    else
        gpg --yes $rcpt -o $tmp --encrypt -- $input; or return 1
    end
    command mv -fT -- $tmp $output; or __kc_die "cannot write $output"; or return 1
    set -g tmp ''
    __kc_warn "wrote $output"

    if test $remove -eq 1
        __kc_is_encrypted $output; or __kc_die "not removing $input: $output is not valid encrypted output"; or return 1
        command rm -rf -- $input
        __kc_warn "removed $input"
    end
end

function __kc_decrypt
    set -l try
    if test $archive -eq 1; and test $dir_required -eq 1
        __kc_die "--archive conflicts with a trailing slash on the output"; or return 1
    end

    if test (count $keys) -eq 0
        set -l rcpts (__kc_packets $input | string replace -rf '^:pubkey enc packet:.*keyid ([0-9A-Fa-f]+).*' '$1')
        if test (count $rcpts) -gt 0
            __kc_detect_card
            set -l matched 0
            for r in $rcpts
                # a hidden recipient (all zeros) cannot be checked
                string match -qr '^0*$' -- $r; and set matched 1
                if test -n "$card_enc"; and test (string upper (string sub -s -16 -- $card_enc)) = (string upper $r)
                    set matched 1
                end
            end
            if test $matched -eq 0
                set -l cardid none
                test -z "$card_enc"; or set cardid (string sub -s -16 -- $card_enc)
                set -g key_answer ''
                __kc_ask_key "file is encrypted to: $rcpts; connected card key: $cardid (blank lets gpg choose)"; or return 1
                test -z "$key_answer"; or set -g keys $key_answer
            end
        end
    end
    for r in $keys
        set -a try --try-secret-key $r
    end

    if test -z "$output"
        switch $input
            case '*.gpg' '*.pgp' '*.asc'
                set -g output (string replace -r '\.[^.]*$' '' -- $input)
        end
        if test $archive -eq 0 # extracting: name the directory after the archive
            switch $output
                case '*.tar.*'
                    set -g output (string replace -r '^(.*)\.tar\..*$' '$1' -- $output)
                case '*.tar' '*.tgz' '*.tbz' '*.tbz2' '*.txz' '*.tzst'
                    set -g output (string replace -r '\.[^.]*$' '' -- $output)
            end
        end
        test -n "$output"; or __kc_die "cannot derive an output name from $input; pass one with --output"; or return 1
    end
    test "$output" != "$input"; or __kc_die "output is the same as input"; or return 1
    __kc_check_output; or return 1

    # Decrypt to a temp file first: a bad or truncated file never touches the
    # output. Sibling of the output when its parent exists (cheap final mv).
    if test -d (path dirname -- $output)
        set -g tmp (mktemp -- "$output.XXXXXX")
    else
        set -g tmp (mktemp)
    end
    gpg --yes $try -o $tmp --decrypt -- $input; or return 1

    set -l first ''
    test $archive -eq 1; or set first (tar -tf $tmp 2>/dev/null | head -n 1)
    if test $dir_required -eq 1; and test -z "$first"
        __kc_die "cannot extract into $output/: payload is not a tar archive"; or return 1
    end
    if test -n "$first"
        if not test -d $output; and test $make_dir -eq 0
            isatty stdin; and isatty stderr; or __kc_die "output directory $output does not exist -- pass --mkdir to create it"; or return 1
            printf '%s: create directory %s? [Y/n] ' $prog $output >&2
            set -l ans (head -n 1)
            not string match -qri '^n' -- $ans; or __kc_die "not extracting: $output does not exist (input kept)"; or return 1
        end
        command mkdir -p -- $output; or return 1
        tar -xf $tmp -C $output; or return 1
    else
        if test $make_dir -eq 1
            command mkdir -p -- (path dirname -- $output); or return 1
        else if not test -d (path dirname -- $output)
            __kc_die "parent directory of $output does not exist -- pass --mkdir to create it"; or return 1
        end
        command mv -fT -- $tmp $output; or __kc_die "cannot write $output"; or return 1
        set -g tmp ''
    end
    __kc_warn "wrote $output"

    if test $remove -eq 1
        command rm -f -- $input
        __kc_warn "removed $input"
    end
end

# Open With entries: file|Name|Comment|key-crypt arguments (no '|' in the text).
function __kc_entries
    printf '%s\n' \
        'key-crypt.desktop|Key-Crypt|Encrypt or decrypt with the OpenPGP key on your smartcard|' \
        'key-crypt-preset.desktop|Key-Crypt (Remove Original)|Same, but overwrites existing output and deletes the original file or directory|--preset'
end

# Writes a standalone fish script at ~/.local/bin/key-crypt that sources this
# function file and calls key-crypt -- .desktop Exec lines need a real
# executable, not a shell function. Registers the Open With entries too.
function __kc_install
    set -l bin $HOME/.local/bin/key-crypt
    set -l app $HOME/.local/share/applications
    set -l src (realpath -- (status filename))

    # The path lands inside a quoted .desktop Exec line, so keep it plain.
    string match -qr '^[A-Za-z0-9_./+-]+$' -- $bin
    or __kc_die "install path has characters unsafe for a .desktop file: $bin"; or return 1

    command mkdir -p -- (path dirname -- $bin) $app; or return 1
    printf '%s\n' \
        '#!/usr/bin/env -S fish --no-config' \
        '# Generated by key-crypt --install. Re-run --install to refresh.' \
        "source "(string escape -- $src) \
        'key-crypt $argv' \
        'exit $status' >$bin
    or __kc_die "cannot write $bin"; or return 1
    command chmod 755 -- $bin; or return 1

    for line in (__kc_entries)
        set -l f (string split '|' -- $line)
        set -l args ''
        test -n "$f[4]"; and set args " $f[4]"
        begin
            printf '%s\n' '[Desktop Entry]' 'Type=Application' "Name=$f[2]" "Comment=$f[3]"
            printf '%s\n' 'Exec=bash -c "'$bin$args' \\\\"\\\\$1\\\\"; read -rp \'Press Enter to close.\' _" bash %f'
            printf '%s\n' 'Icon=dialog-password' 'Terminal=true' 'Categories=Utility;Security;' 'MimeType=application/pgp-encrypted;inode/directory;'
        end >$app/$f[1]
        __kc_warn "installed $app/$f[1]"
    end
    __kc_warn "installed $bin"
    command -q update-desktop-database; and update-desktop-database $app

    contains -- (path dirname -- $bin) $PATH; or __kc_warn "note: "(path dirname -- $bin)" is not in your PATH"
end

function __kc_uninstall
    set -l app $HOME/.local/share/applications
    set -l files $HOME/.local/bin/key-crypt
    for line in (__kc_entries)
        set -a files $app/(string split '|' -- $line)[1]
    end
    set -l n 0
    for f in $files
        test -e $f; or test -L $f; or continue
        command rm -f -- $f
        __kc_warn "removed $f"
        set n 1
    end
    if test $n -eq 1
        command -q update-desktop-database; and update-desktop-database $app
    else
        __kc_warn "nothing to remove (not installed)"
    end
end

function __kc_body
    # --install/--uninstall must be the only argument; --help overrides them.
    if contains -- --install $argv; or contains -- --uninstall $argv
        if contains -- -h $argv; or contains -- --help $argv
            __kc_usage
            return 0
        end
        if test (count $argv) -ne 1
            __kc_warn "--install/--uninstall cannot be combined with other options or arguments (see --help)"
            return 2
        end
        if test "$argv[1]" = --install
            __kc_install
        else
            __kc_uninstall
        end
        return $status
    end

    # -e/--extract are silent no-ops: extracting is the default.
    argparse -n $prog h/help 'i/input=' 'o/output=' 'k/key=+' f/force r/remove m/mkdir a/archive p/preset e/extract -- $argv
    or return 2
    if set -q _flag_help
        __kc_usage
        return 0
    end

    set -g force 0
    set -g remove 0
    set -g make_dir 0
    set -g archive 0
    set -g dir_required 0
    set -g keys $_flag_key
    set -q _flag_force; and set force 1
    set -q _flag_remove; and set remove 1
    set -q _flag_mkdir; and set make_dir 1
    set -q _flag_archive; and set archive 1
    if set -q _flag_preset
        set force 1
        set remove 1
        set make_dir 1
    end

    # Positionals: with --input the sole positional is the output, else input then output.
    set -g input ''
    set -g output ''
    set -q _flag_input; and set -g input $_flag_input
    set -q _flag_output; and set -g output $_flag_output
    if test -n "$input"
        test (count $argv) -le 1; or __kc_die "too many arguments (see --help)"; or return 1
        if test (count $argv) -eq 1
            test -z "$output"; or __kc_die "output given twice (see --help)"; or return 1
            set -g output $argv[1]
        end
    else
        if test (count $argv) -lt 1; or test (count $argv) -gt 2
            __kc_usage >&2
            return 2
        end
        set -g input $argv[1]
        if test (count $argv) -eq 2
            test -z "$output"; or __kc_die "output given twice (see --help)"; or return 1
            set -g output $argv[2]
        end
    end

    if not type -q gpg
        __kc_die "gpg not found"
        return 1
    end
    if not type -q tar
        __kc_die "tar not found"
        return 1
    end
    test -e $input; or __kc_die "input not found: $input"; or return 1
    set -g input (string replace -r '(.)/$' '$1' -- $input)

    # A trailing slash on the output means "this must be a directory": note
    # it, then drop it so temp names and existence checks use the plain path.
    while string match -qr '.+/$' -- $output
        set -g output (string replace -r '/$' '' -- $output)
        set -g dir_required 1
    end

    if __kc_is_encrypted $input
        __kc_decrypt
    else
        __kc_encrypt
    end
end

function key-crypt --description 'Encrypt or decrypt a file or directory with an OpenPGP smartcard key'
    set -g prog (status current-function)
    set -g tmp ''
    set -g card_enc ''
    set -g key_answer ''

    __kc_body $argv
    set -l st $status

    # Mirrors the fish_exit-trap cleanup of the standalone script, scoped to
    # this call instead of the whole shell.
    test -z "$tmp"; or command rm -rf -- $tmp
    set -e prog tmp card_enc key_answer keys input output force remove make_dir archive dir_required c_head c_name c_flag c_arg c_dim c_reset 2>/dev/null

    return $st
end
