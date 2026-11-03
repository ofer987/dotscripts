---
name: release-branch-validator
description: Validates that a release branch contains the full patch of all expected release tags. Use when on a releases/<MAJOR>.<MINOR>.<PATCH> branch and the user asks to validate the release, check release history, verify patch chain of release tags, or audit release branch integrity.
disable-model-invocation: true
---

# Release Branch Validator

Performs the following validation on the current `releases/<MAJOR>.<MINOR>.<PATCH>` branch:

1. **Release tag check** — for each patch number that has a branch on the remote (from Step 2), confirms that the corresponding tag `release-<MAJOR>.<MINOR>.<N>` exists. Patch numbers without a remote branch are silently skipped.

Branches that do not exist on the remote are silently skipped — only branches that exist but were **not merged** cause a failure.

## Example Outputs

### Case 1 — Not the latest patch (FAIL)

Checked out `releases/5.80.104` while `releases/5.80.106` exists on the remote.

```
Release Branch Validation: FAILED

Branch:  releases/5.80.104

Latest patch check: FAIL
  Current : releases/5.80.104
  Latest  : releases/5.80.106
  This branch is not the latest — releases/5.80.106 exists on the remote.

Release tag check: 96 tags checked (branches with remote) — all present

  release-5.80.0   ✓
  ...
  release-5.80.104 ✓
```

### Case 2 — Latest patch but a release tag is missing (FAIL)

On `releases/5.80.106` but the tag `release-5.80.105` was never created.

```
Release Branch Validation: FAILED

Branch:  releases/5.80.106

Latest patch check: PASS

Release tag check: 1 of 98 tags missing (branches with remote only)

  release-5.80.0   ✓
  ...
  release-5.80.104 ✓
  release-5.80.105 ✗  (missing)
  release-5.80.106 ✓
```

### Case 3 — Latest patch, all tags present (PASS)

On `releases/5.80.106` with all 98 tags in place.

```
Release Branch Validation: PASSED

Branch:  releases/5.80.106

Latest patch check: PASS

Release tag check: 98 tags checked (branches with remote) — all present

  release-5.80.0   ✓
  ...
  release-5.80.106 ✓
```

## Permissions

This skill is **read-only**. Do NOT create, modify, or delete any files, branches, or tags. Only use read-only git commands (`git rev-parse`, `git branch -r`, `git merge-base`, `git fetch`, `git log`) and report results. If a check fails, report the failure — do not attempt to fix it.

## Prerequisites

- The current branch must match the pattern `releases/<MAJOR>.<MINOR>.<PATCH>`.
- If the current branch does not match, stop and tell the user this skill only applies to release branches. Suggest they check out one first, e.g. `git checkout releases/5.80.101`.

## Workflow

### Step 1: Identify the current release branch

```bash
git rev-parse --abbrev-ref HEAD
```

Parse the branch name to extract `MAJOR`, `MINOR`, and `PATCH`. If the branch is not in the form `releases/<MAJOR>.<MINOR>.<PATCH>`, report an error and suggest the user check out a release branch first, e.g.:

```
git checkout releases/5.80.101
```

Then stop.

### Step 2: Fetch remote refs and discover existing branches

Fetch the relevant remote refs for the entire `<MAJOR>.<MINOR>` series, then list all patch branches that exist on the remote:

```bash
git fetch origin 'refs/heads/releases/<MAJOR>.<MINOR>.*:refs/remotes/origin/releases/<MAJOR>.<MINOR>.*'
git branch -r --list 'origin/releases/<MAJOR>.<MINOR>.*'
```

Parse the patch number from each listed branch.

### Step 3: Check release tags

Fetch remote tags for the series:

```bash
git fetch origin --tags
```

Using the set of patch numbers that have a branch on the remote (discovered in Step 2, including the current branch's own patch number), check whether the corresponding tag exists for each:

```bash
git rev-parse --verify "refs/tags/release-<MAJOR>.<MINOR>.<N>" >/dev/null 2>&1
```

### Step 4: Report results

Report the results of the release tag check (Step 3).

#### All checks passed

```
Release Branch Validation: PASSED

Branch:    releases/<MAJOR>.<MINOR>.<PATCH>

Release tag check: <N> tags checked (branches with remote) — all present

  release-<MAJOR>.<MINOR>.0  ✓
  release-<MAJOR>.<MINOR>.1  ✓
  ...
  release-<MAJOR>.<MINOR>.<PATCH>  ✓
```

#### One or more failures

```
Release Branch Validation: FAILED

Branch:       releases/<MAJOR>.<MINOR>.<PATCH>

Release tag check: <missing-count> of <N> tags missing (branches with remote only)

  release-<MAJOR>.<MINOR>.0   ✓
  release-<MAJOR>.<MINOR>.1   ✗  (missing)
  release-<MAJOR>.<MINOR>.2   ✓
  ...
```

After reporting, stop.

### Step 5: Edge case — patch version is 0

If the current branch is `releases/<MAJOR>.<MINOR>.0`, there are no preceding patches to validate. The only tag to check is `release-<MAJOR>.<MINOR>.0`. Report:

```
Release Branch Validation: PASSED (baseline)

Branch:   releases/<MAJOR>.<MINOR>.0  (latest)
This is the baseline patch release — no preceding patches to validate.

Release tag check:
  release-<MAJOR>.<MINOR>.0  ✓  (or ✗ if missing)
```

If the tag is missing, report it as a failure in the output.

## Script

A ready-to-run implementation of this skill lives alongside this file:

```
.cursor/skills/release-branch-validator/validate-release-branch.sh
```

Run it from the root of any repository:

```bash
bash ~/.cursor/skills/release-branch-validator/validate-release-branch.sh
```

The script is equivalent to the manual workflow above and exits with code `0` on success, `1` on failure.
