# Reference — Environment Branch Discovery

## Table of Contents

- [How to Find the Deployed `releases/*` Branch per Environment](#how-to-find-the-deployed-releases-branch-per-environment)
- [Branch Version Semantics](#branch-version-semantics)
- [Identifying Whether PPE and Prod Differ](#identifying-whether-ppe-and-prod-differ)
- [Cherry-pick vs Merge commit behaviour](#cherry-pick-vs-merge-commit-behaviour)
- [GitHub Branch Protection Notes](#github-branch-protection-notes)
- [Rollback / Undo](#rollback--undo)

---

## How to Find the Deployed `releases/*` Branch per Environment

Each AEM author environment exposes a publicly reachable version endpoint. The script
fetches these automatically; you can also query them manually with `curl`:

| Environment | URL                                                                                                   |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| UAT         | `https://author-p163316-e1779207.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json` |
| PPE         | `https://author-p163316-e1779165.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json` |
| Prod        | `https://author-p163316-e1779099.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json` |

The response may include a sub-patch suffix:

```
5.83.86.2026_0724_1105440_0008701135
```

Discard everything after the third dot. Only `<MAJOR>.<MINOR>.<PATCH>` is used to
construct the `releases/*` branch name (e.g. `releases/5.83.86`).

```bash
curl -sf <URL> | cut -d. -f1-3
```

---

## Branch Version Semantics

This repo uses **semantic-style** branch names: `releases/<MAJOR>.<MINOR>.<PATCH>`.

| Segment | Meaning                                  |
| ------- | ---------------------------------------- |
| MAJOR   | Product generation (rarely changes)      |
| MINOR   | Sprint / feature release increment       |
| PATCH   | Hotfix increment within a sprint release |

A typical promotion sequence:

```
releases/5.85.7  →  UAT validates  →  promoted to PPE  →  promoted to Prod
releases/5.85.8  →  next UAT candidate
```

UAT always runs the **newest** patch; Prod usually lags behind by one or more patches.

---

## Identifying Whether PPE and Prod Differ

PPE and Prod share the same branch **only while no promotion is in flight**.
They diverge when:

- A build has been promoted to PPE but Prod has not yet been updated.
- A hotfix is applied to Prod on a different branch while PPE runs a newer one.

**You do not need to determine this manually.** You can omit `--prod` to let the script auto-discover Prod,
or supply `--prod` to override the discovered branch. After resolving the latest patch for each environment,
the script compares the two resolved branch names. If they are identical it logs:

```
→ Prod (releases/5.85.17) == PPE (releases/5.85.17) after patch resolution — skipping duplicate Prod port.
```

and proceeds with only UAT and PPE targets. If they differ it logs:

```
→ Prod (releases/5.84.9) differs from PPE (releases/5.85.17) — adding separate Prod target.
```

and cherry-picks into all three.

---

## Cherry-pick vs Merge commit behaviour

| Situation                          | Recommended approach                   |
| ---------------------------------- | -------------------------------------- |
| PR has 1–10 commits                | Cherry-pick individual SHAs in order   |
| PR is a single squash commit       | Cherry-pick that one commit            |
| PR used a merge commit (no squash) | `git cherry-pick -m 1 <merge-sha>`     |
| PR spans hundreds of commits       | Squash locally first, then cherry-pick |

The `port-pr.sh` script handles all of these automatically by checking the PR's
commit list via `gh pr view --json commits`.

---

## GitHub Branch Protection Notes

The `releases/*` branches are branch-protected.
Port branches must go through a PR — **never force-push directly to a `releases/*` branch**.

The `port-pr.sh` script pushes to a `port/pr-<N>-to-releases-X-Y-Z` branch and
gives you a compare URL or offers to open a PR via `gh pr create`.

---

## Rollback / Undo

If a port PR was merged by mistake:

```bash
# Revert the merge commit on the target branch
git checkout releases/X.Y.Z
git revert -m 1 <merge-commit-sha>
git push origin releases/X.Y.Z
```

Or open a revert PR via:

```bash
gh pr create --base releases/X.Y.Z --head revert/... \
  --title "Revert port of PR #<N> from releases/X.Y.Z"
```
