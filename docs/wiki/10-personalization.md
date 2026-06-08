# 10. PERSONALIZATION

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Installation](9-installation.md) | **10. Personalization** | [11. Viewing This Manual](11-viewing-this-manual.md)

---

Sensitive credentials and machine-specific settings are kept out of version
control in a private directory at ~/.config/.user-dots/fish/. Two files are
sourced automatically by config.fish if they exist:

    ~/.config/.user-dots/fish/
    ├── secrets.fish   API keys, tokens, passwords, personal identifiers
    └── local.fish     Machine-specific paths and environment variables

fish_variables (auto-managed by fish) is excluded from this repo via
.gitignore. Do not commit it.

## secrets.fish

Store anything you would not commit to a public repo: API keys, auth tokens,
passwords, and personal identifiers.

    set -gx MY_NAME "Your Name"
    set -gx MY_EMAIL "you@example.com"
    set -gx GPG_RECIPIENT "you@example.com"
    set -gx GITHUB_TOKEN ghp_yourTokenHere
    set -gx OPENAI_API_KEY sk-proj-yourKeyHere
    set -gx GITEA_TOKEN yourGiteaTokenHere
    set -gx GITEA_CHOSEN_LOGIN your.gitea.instance
    set -gx KOPIA_PASSWORD yourKopiaPassword

## local.fish

Store paths and variables specific to one machine — things that would be
wrong on any other system.

    # CDPATH — directories searched by cd
    set -gx CDPATH . /home/youruser/projects /home/youruser

    # Path to your shared .gitignore boilerplate
    set -gx GITIGNORE_BOILERPLATE ~/.config/git/gitignore_boilerplate

    # SSH shortcuts
    abbr -a sshr 'ssh you@your-server.local'
    abbr -a sshw 'ssh you@work-server.example.com'

    # Docker context shortcuts
    abbr -a dcr 'docker context use my-remote-server'
    abbr -a dcw 'docker context use work-server'

Both files are sourced at the end of config.fish with an existence check so
the public config works cleanly on any machine without the private repo.

---
