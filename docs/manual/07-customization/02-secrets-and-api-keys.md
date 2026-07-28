---
title: Secrets and API Keys
---

    $__fish_user_dots_path/secrets.fish

Store API tokens, GPG keys, private credentials here. This file is never
committed. It is sourced by local.fish directly, not by config.fish.

`local.fish` is sourced at the end of config.fish on every interactive
session, so it and its companion secrets.fish can override anything set
earlier.

