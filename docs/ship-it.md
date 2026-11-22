# Shipping this project

Instructions for `/ship-it` and its steps. Each `##` section is read by the step of the same
name; anything left out uses that step's defaults.

## merge-it
- Merge method: merge commit.
- Always ask before merging, unless the user has asked for these exact PRs to be merged.
- **Batch independent PRs.** When none of the PRs is stacked on another, and each is mergeable
  with `CI / test (pull_request)` green on its current head, merge them back to back without
  waiting for `main`'s run on each merge commit. Branch protection does not require a PR to be
  up to date with `main`, and each PR has already passed on its own head.
- **Then watch `main` once.** `main`'s runs queue (`concurrency` in `ci.yml`): they are never
  cancelled, because their docs job deploys the site and commits regenerated docs. Watch the run
  on the last merge commit, and the `chore(docs): regenerate ...` commit it makes when the
  generated docs changed, before reporting.
- **If that run fails**, find the merge that broke it: check out each merge commit of the batch,
  oldest first, and run `fish tests/run-tests.fish`. The first that fails is the culprit. Fix it
  forward on a new branch.
- Stacked PRs still merge bottom-up, each retargeted onto `main` once its parent merges.
- A newer push to a PR cancels the run it supersedes. A cancelled run of a superseded commit is
  not a failure.
