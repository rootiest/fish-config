# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for key-crypt.
#
# Positionals are the input and output paths, so file completion stays on.
# -e/--extract is accepted but a silent no-op (extracting is the default), so
# it is not offered.

complete -c key-crypt -s h -l help -d 'Show help message'
complete -c key-crypt -s i -l input -r -F -d 'Directory, file, or encrypted file to process'
complete -c key-crypt -s o -l output -r -F -d 'Where to write the result'
# -k takes a key ID or fingerprint; offer the secret keys gpg knows about.
# Empty (and harmless) when gpg is missing or the keyring has none.
complete -c key-crypt -s k -l key -x -a '(__key_crypt_complete_keys)' -d 'Key ID or fingerprint (repeatable)'
complete -c key-crypt -s f -l force -d 'Overwrite an existing output'
complete -c key-crypt -s a -l archive -d 'Decrypt: keep the archive instead of extracting'
complete -c key-crypt -s m -l mkdir -d 'Decrypt: create the output directory without asking'
complete -c key-crypt -s p -l preset -d 'Hands-off mode: --force --mkdir --remove'
complete -c key-crypt -s r -l remove -d 'Delete the input after a successful run'
# --install/--uninstall are only valid as the sole argument.
complete -c key-crypt -n 'test (count (commandline -opc)) -eq 1' -l install -d 'Install standalone wrapper and Open With entries'
complete -c key-crypt -n 'test (count (commandline -opc)) -eq 1' -l uninstall -d 'Remove the wrapper and Open With entries'

function __key_crypt_complete_keys
    type -q gpg; or return 0
    command gpg --batch --list-secret-keys --with-colons 2>/dev/null | string match -r '^fpr:.*' | string split -f10 :
    return 0
end
