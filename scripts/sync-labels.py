#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   sync-labels.py [--dry-run] [--self-test]
#
# DESCRIPTION
#   Syncs the label taxonomy from the canonical Gitea repo to the GitHub
#   mirror. Gitea is the source of truth: labels are managed there, in the
#   web UI or via its API, and this script makes GitHub match.
#
#   Mirroring copies files, not repository settings, so labels do not travel
#   with a push. They matter on the mirror anyway, because GitHub reads the
#   same .github/ISSUE_TEMPLATE/ files and silently drops a labels: entry
#   naming a label that does not exist there.
#
#   Three actions, decided by comparing the two sets by label name:
#
#     missing on GitHub          created
#     color or description drift updated
#     extra on GitHub            deleted only if no issue or PR carries it,
#                                otherwise left alone and reported
#
#   The usage check is what keeps an unattended scheduled run from stripping
#   a label off somebody's issue. An extra label that is in use is reported
#   with its count and requires a human decision.
#
# ARGUMENTS
#   --dry-run    Print the plan and exit without changing anything. Works
#                without a token, using GitHub's unauthenticated read quota.
#   --self-test  Check the diff logic against in-memory fixtures and exit.
#                Runs offline; makes no network calls.
#
# ENVIRONMENT
#   GH_MIRROR_TOKEN  GitHub token with Issues: read and write (labels live
#                    under Issues) and Pull requests: read (so the usage
#                    check sees labels attached to PRs). Required unless
#                    --dry-run or --self-test.
#
# EXIT STATUS
#   0  Success, or a dry run that completed.
#   1  An API call failed, the token is missing, or a self-test failed.
#
# NOTES
#   Labels are matched by name, so renaming one on Gitea reads here as a
#   delete plus a create: the new name is created, and the old one is pruned
#   only if unused. The two forges share no stable label ID, so a rename
#   cannot be tracked across them.
#
#   GitHub has no exclusive labels. Gitea's one-of enforcement on Priority/,
#   Reviewed/, and Status/ does not survive the trip and holds by convention
#   on the mirror.

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

GITEA_API = "https://git.rootiest.dev/api/v1"
GITEA_REPO = "Rootiest/fish-config"
GITHUB_API = "https://api.github.com"
GITHUB_REPO = "rootiest/fish-config"
TOKEN_ENV = "GH_MIRROR_TOKEN"
TIMEOUT = 30


class SyncError(RuntimeError):
    """An API call failed, or the environment is not usable."""


# --------------------------------------------------------------------------
# Pure diff core. No I/O lives below this line until the HTTP section, so
# --self-test can exercise the decision logic offline.
# --------------------------------------------------------------------------


def normalize(label):
    """Reduce a forge's label dict to (name, color, description).

    Gitea returns colors bare ("00838f"), GitHub sometimes with a leading
    "#", and either may use mixed case; a description may be null on GitHub
    but "" on Gitea. Without this the two sets never compare equal and every
    run would rewrite every label.
    """
    return (
        label["name"],
        (label.get("color") or "").lstrip("#").lower(),
        label.get("description") or "",
    )


def plan(source, target):
    """Compare two label lists and return the work to do.

    Returns (to_create, to_update, extras): two lists of label dicts and a
    list of names present on the target but not the source. Deciding whether
    an extra is safe to delete needs the network, so that is left to the
    caller.
    """
    src = {name: (color, desc) for name, color, desc in map(normalize, source)}
    tgt = {name: (color, desc) for name, color, desc in map(normalize, target)}

    to_create = [
        {"name": name, "color": src[name][0], "description": src[name][1]}
        for name in sorted(src.keys() - tgt.keys())
    ]
    to_update = [
        {
            "name": name,
            "color": src[name][0],
            "description": src[name][1],
            "was": tgt[name],
        }
        for name in sorted(src.keys() & tgt.keys())
        if src[name] != tgt[name]
    ]
    extras = sorted(tgt.keys() - src.keys())
    return to_create, to_update, extras


# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------


def request(url, token=None, method="GET", payload=None):
    body = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Accept", "application/json")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        raise SyncError(f"{method} {url} -> HTTP {exc.code}: {detail}") from None
    except urllib.error.URLError as exc:
        raise SyncError(f"{method} {url} -> {exc.reason}") from None


def paginate(url_template, token=None, per_page=50):
    """Collect every page of a list endpoint.

    url_template takes {page} and {per_page}. Both forges stop returning
    full pages at the end, which is the signal used here rather than trying
    to parse differing Link headers.
    """
    collected = []
    page = 1
    while True:
        batch = request(
            url_template.format(page=page, per_page=per_page), token=token
        )
        if not batch:
            break
        collected.extend(batch)
        if len(batch) < per_page:
            break
        page += 1
    return collected


def quoted(name):
    """URL-encode a label name. Names carry '/', ' ', '&' and apostrophes."""
    return urllib.parse.quote(name, safe="")


def fetch_gitea_labels():
    return paginate(
        f"{GITEA_API}/repos/{GITEA_REPO}/labels?limit={{per_page}}&page={{page}}"
    )


def fetch_github_labels(token):
    return paginate(
        f"{GITHUB_API}/repos/{GITHUB_REPO}/labels?per_page={{per_page}}&page={{page}}",
        token=token,
    )


def usage_count(name, token):
    """How many issues or PRs on the mirror carry this label.

    Caps at 100; the exact number past that does not change the decision,
    which is only ever "zero" versus "not zero".
    """
    items = request(
        f"{GITHUB_API}/repos/{GITHUB_REPO}/issues"
        f"?labels={quoted(name)}&state=all&per_page=100",
        token=token,
    )
    return len(items or [])


def create_label(label, token):
    request(
        f"{GITHUB_API}/repos/{GITHUB_REPO}/labels",
        token=token,
        method="POST",
        payload={
            "name": label["name"],
            "color": label["color"],
            "description": label["description"],
        },
    )


def update_label(label, token):
    request(
        f"{GITHUB_API}/repos/{GITHUB_REPO}/labels/{quoted(label['name'])}",
        token=token,
        method="PATCH",
        payload={
            "new_name": label["name"],
            "color": label["color"],
            "description": label["description"],
        },
    )


def delete_label(name, token):
    request(
        f"{GITHUB_API}/repos/{GITHUB_REPO}/labels/{quoted(name)}",
        token=token,
        method="DELETE",
    )


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------


def emit_summary(lines):
    """Append a run summary to the CI step summary, when running under CI."""
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    try:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    except OSError as exc:
        print(f"note: could not write step summary: {exc}", file=sys.stderr)


# --------------------------------------------------------------------------
# Self-test
# --------------------------------------------------------------------------


def self_test():
    checks = 0

    def check(condition, message):
        nonlocal checks
        checks += 1
        if not condition:
            raise AssertionError(message)

    # Identical sets produce no work. This is the case every scheduled run
    # hits once the two forges agree, so it must be exactly empty rather
    # than merely small.
    same = [{"name": "Kind/Bug", "color": "ee0701", "description": "Broken"}]
    create, update, extras = plan(same, list(same))
    check(create == [] and update == [] and extras == [], "identical sets differ")

    # Cosmetic representation differences are not drift. A "#" prefix,
    # uppercase hex, and null-versus-empty description all appear in real
    # API responses.
    create, update, extras = plan(
        [{"name": "A", "color": "00838F", "description": ""}],
        [{"name": "A", "color": "#00838f", "description": None}],
    )
    check(update == [], "cosmetic color/description difference reported as drift")

    # A real difference in either field is drift.
    _, update, _ = plan(
        [{"name": "A", "color": "111111", "description": "new"}],
        [{"name": "A", "color": "222222", "description": "old"}],
    )
    check(len(update) == 1 and update[0]["color"] == "111111", "color drift missed")
    _, update, _ = plan(
        [{"name": "A", "color": "111111", "description": "new"}],
        [{"name": "A", "color": "111111", "description": "old"}],
    )
    check(len(update) == 1, "description drift missed")

    # Missing and extra are classified by direction, not lumped together.
    create, update, extras = plan(
        [{"name": "keep", "color": "1", "description": ""},
         {"name": "add", "color": "2", "description": ""}],
        [{"name": "keep", "color": "1", "description": ""},
         {"name": "stale", "color": "3", "description": ""}],
    )
    check([c["name"] for c in create] == ["add"], "missing label not queued")
    check(extras == ["stale"], "extra label not detected")
    check(update == [], "unchanged label queued for update")

    # An empty source must not be read as "delete everything silently" --
    # extras still route through the caller's usage check.
    create, update, extras = plan([], [{"name": "x", "color": "1", "description": ""}])
    check(create == [] and update == [] and extras == ["x"], "empty source mishandled")

    # Names that need URL encoding survive the round trip.
    check(quoted("Area/Prompt & Theme") == "Area%2FPrompt%20%26%20Theme", "bad quoting")
    check(quoted("Reviewed/Won't Fix") == "Reviewed%2FWon%27t%20Fix", "bad quoting")
    checks += 2

    # Output ordering is stable, so a run's log is diffable against the last.
    create, _, extras = plan(
        [{"name": "b", "color": "1", "description": ""},
         {"name": "a", "color": "1", "description": ""}],
        [{"name": "z", "color": "1", "description": ""},
         {"name": "y", "color": "1", "description": ""}],
    )
    check([c["name"] for c in create] == ["a", "b"], "creates not sorted")
    check(extras == ["y", "z"], "extras not sorted")

    print(f"self-test: {checks} checks passed")
    return 0


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------


def run(dry_run):
    token = os.environ.get(TOKEN_ENV)
    if not token and not dry_run:
        raise SyncError(
            f"{TOKEN_ENV} is not set. Add a GitHub token to the Gitea repo's "
            f"Actions secrets as {TOKEN_ENV}, with Issues: read and write "
            "plus Pull requests: read, scoped to " + GITHUB_REPO + "."
        )

    source = fetch_gitea_labels()
    if not source:
        raise SyncError(
            "Gitea returned no labels. Refusing to continue, since treating "
            "that as the source of truth would propose deleting every label "
            "on the mirror."
        )
    target = fetch_github_labels(token)
    to_create, to_update, extras = plan(source, target)

    prefix = "would " if dry_run else ""
    log = [f"Gitea: {len(source)} labels    GitHub: {len(target)} labels", ""]

    for label in to_create:
        log.append(f"  {prefix}create  {label['name']}")
        if not dry_run:
            create_label(label, token)

    for label in to_update:
        old_color, old_desc = label["was"]
        changed = []
        if old_color != label["color"]:
            changed.append(f"color {old_color} -> {label['color']}")
        if old_desc != label["description"]:
            changed.append("description")
        log.append(f"  {prefix}update  {label['name']}  ({', '.join(changed)})")
        if not dry_run:
            update_label(label, token)

    skipped = []
    for name in extras:
        count = usage_count(name, token)
        if count:
            skipped.append((name, count))
            log.append(
                f"  KEPT     {name}  (in use by {count} issue/PR"
                f"{'s' if count != 1 else ''} -- delete by hand if intended)"
            )
        else:
            log.append(f"  {prefix}delete  {name}  (unused)")
            if not dry_run:
                delete_label(name, token)

    total = len(to_create) + len(to_update) + len(extras) - len(skipped)
    if total == 0 and not skipped:
        log.append("  no changes -- the mirror already matches Gitea")
    log.append("")
    log.append(
        f"{'planned' if dry_run else 'applied'}: "
        f"{len(to_create)} created, {len(to_update)} updated, "
        f"{len(extras) - len(skipped)} deleted, {len(skipped)} kept in use"
    )

    print("\n".join(log))
    emit_summary(["## Label sync", "", "```", *log, "```"])
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Sync the label taxonomy from Gitea to the GitHub mirror."
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print the plan, change nothing"
    )
    parser.add_argument(
        "--self-test", action="store_true", help="check the diff logic offline"
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()
    try:
        return run(args.dry_run)
    except SyncError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
