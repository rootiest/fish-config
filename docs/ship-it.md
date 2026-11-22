# Shipping this project

Instructions for `/ship-it` and its steps. Each `##` section is read by the step of the same
name; anything left out uses that step's defaults.

## merge-it
- Merge method: merge commit.
- Always ask before merging, unless the user has asked for these exact PRs to be merged.
- **Branch protection sets the pace.** A PR that is behind `main` cannot merge, and
  `CI / test (pull_request)` must pass on the head it merges with. So after each merge the next
  PR needs "Update branch", and its PR run on the new head has to pass: that wait cannot be
  skipped.
- **Skip the wait on `main`.** Do not wait for `main`'s run on a merge commit before starting on
  the next PR. Update the next PR straight after the merge and watch only its PR run. A newer
  push to a PR cancels the run it supersedes (`concurrency` in `ci.yml`), and a cancelled run
  of a superseded commit is not a failure.
- **The docs commit.** `main`'s run commits regenerated docs (`chore(docs): regenerate ...`,
  as Rootiest CI) a few minutes after a merge that changes them. If it lands while the next PR's
  run is going, that PR is behind again: update it once more. After the last merge, watch
  `main`'s run on the last merge commit (and its docs commit, if one comes) before reporting.
- If `main`'s run fails after a batch, find the merge that broke it by running
  `fish tests/run-tests.fish` at each merge commit since the last green one, oldest first.
