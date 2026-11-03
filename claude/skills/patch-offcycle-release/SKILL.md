---
name: patch-offcycle-release
description: Cherry-pick a PR that was merged into `release` into the `releases/*` branches deployed to UAT, PPE, and Prod, then open a GitHub Draft PR for each target branch so a Deployer can create the new releases/* branch and promote to each environment. Handles branch discovery, latest-patch resolution, commit extraction, cherry-pick automation, conflict guidance, and Draft PR creation. Use when the user asks to backport, port, or merge a release-branch PR into environment branches, mentions UAT/PPE/Prod backport, off-cycle release, patch release, hotfix release, or says "merge PR into releases branches".
---

# Patch Off-Cycle Release

Port a merged or closed PR from `release` into the `releases/*` branches currently deployed to
UAT, PPE, and (optionally) Prod.

## What this skill does NOT do

- It does not create `releases/*` branches directly — that step requires a Deployer.
- It does not trigger Cloud Manager pipelines or promote between environments.

## Prerequisites

- **macOS / Linux:** `git`, `gh` (GitHub CLI, authenticated), `curl`, `jq`, `awk`, `head`, `grep`, `sort`, and `cut`.
- **Windows:** `git`, `gh` (GitHub CLI, authenticated), and PowerShell 7+ (`pwsh`). No additional tools are required — `port-pr.ps1` uses only native PowerShell cmdlets.

## Quick Start

```
/patch-offcycle-release PR=<number>
```

Run the helper script (see step 4) or follow the manual workflow below.

## Workflow

### Step 1 — Validate the Git repository is clean

Before doing anything else, confirm the working tree is in a clean state. Uncommitted
changes can be accidentally included in cherry-picked branches or cause `git checkout`
to fail mid-script.

Run:

```bash
! git status --porcelain | grep -v '^??'
```

The output must be **empty**. Untracked files (`??`) are ignored and do not block
the workflow. Any other output indicates tracked changes that must be resolved first.
Common causes and what to look for:

| `git status --porcelain` prefix | Meaning                                     |
| ------------------------------- | ------------------------------------------- |
| ` M` / `M ` / `MM`              | Modified files (unstaged or staged or both) |
| `A ` / `AM`                     | New files staged but not yet committed      |
| `D ` / ` D`                     | Deleted files (staged or unstaged)          |

If any such output is present, tell the user:

> The Git repository has uncommitted changes. Please commit or stash all staged and
> modified tracked files before running this skill. Run `git status` for details.

Do not automatically ignore any change -- even a simple whitespace change is important.

Do not proceed to Step 2 until `git status --porcelain` returns no output.

### Step 2 — Discover deployed versions (automatic)

The script discovers the deployed version for each environment automatically by fetching
its version endpoint. No manual input is needed.

| Environment | Version endpoint                                                                                      |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| UAT         | `https://author-p163316-e1779207.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json` |
| PPE         | `https://author-p163316-e1779165.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json` |
| Prod        | `https://author-p163316-e1779099.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json` |

The endpoint may return a version with a sub-patch suffix (e.g.
`5.83.86.2026_0724_1105440_0008701135`). The script discards everything after the third
dot, keeping only `<MAJOR>.<MINOR>.<PATCH>` (e.g. `5.83.86`), then constructs the
`releases/<MAJOR>.<MINOR>.<PATCH>` branch name.

It then resolves the **latest patch** in that `<MAJOR>.<MINOR>` series from the remote
(via `git fetch`), because a new `releases/*` branch can only be created on top of the
current latest patch. For example, if UAT reports `5.85.7` but `releases/5.85.17` exists
on the remote, the script targets `releases/5.85.17` and logs the substitution.

After resolving all three, the script compares PPE and Prod: if they are identical it
skips the duplicate Prod port automatically and logs the reason.

> You may override any branch manually with `--uat`, `--ppe`, or `--prod` flags if needed.
> See [REFERENCE.md](./REFERENCE.md) for details.

### Step 3 — Extract commits from the PR (informational)

The script handles this automatically. For reference, the equivalent manual commands are:

```bash
# List commits that the PR added (excluding the merge commit itself)
gh pr view <PR_NUMBER> --json commits --jq '.commits[].oid'

# Get the merge commit SHA (merged PRs only — used as fallback when no individual commits are found)
gh pr view <PR_NUMBER> --json mergeCommit --jq '.mergeCommit.oid'
```

The script prefers cherry-picking **individual commits** in order rather than the merge
commit itself, to keep each environment branch's history clean.

> **Closed PRs:** `gh pr view --json commits` still returns commits for closed (unmerged) PRs
> as long as the head branch has not been deleted. The merge-commit fallback is skipped for
> closed PRs — if no commits are found the script exits with an actionable error.

### Step 4 — Run the helper script

**macOS / Linux** (`port-pr.sh`):

```bash
# Fully automatic - branches are discovered from the environment version endpoints
./scripts/port-pr.sh --pr <PR_NUMBER>

# Manual override if needed
./scripts/port-pr.sh \
  --pr   <PR_NUMBER>      \
  --uat  releases/X.Y.Z  \
  --ppe  releases/A.B.C  \
  --prod releases/P.Q.R
```

**Windows** (`port-pr.ps1`) — uses native PowerShell; no extra tools required:

```powershell
# Fully automatic - branches are discovered from the environment version endpoints
./scripts/port-pr.ps1 -PR <PR_NUMBER>

# Manual override if needed
./scripts/port-pr.ps1 `
  -PR   <PR_NUMBER>     `
  -UAT  releases/X.Y.Z `
  -PPE  releases/A.B.C `
  -Prod releases/P.Q.R
```

The script will:

1. Fetch latest remote state.
2. For each target branch: create a branch, cherry-pick all PR commits,
   push to `origin`, and open a **Draft PR** against that branch.
3. Report any cherry-pick conflicts and pause for manual resolution.

### Step 5 — Resolve conflicts (MANDATORY user action required)

When the script exits with a conflict, **the agent must stop immediately and ask the
user to manually resolve the conflicts before doing anything else.** Do not attempt to
resolve conflicts automatically or guess at a resolution. Do not proceed to the next
environment branch until the user explicitly confirms the conflicts are resolved.

#### Agent must say to the user (word-for-word):

> Cherry-pick conflict detected on **`<TARGET_BRANCH>`**.
>
> Please resolve the conflicts manually:
>
> 1. Run `git status` to see which files have conflict markers.
> 2. Run `git diff` to review each conflict in detail.
> 3. Edit each conflicted file to fix the merge markers (`<<<<<<<`, `=======`, `>>>>>>>`).
> 4. Stage the resolved files: `git add <resolved-files>`
> 5. Complete the cherry-pick: `git cherry-pick --continue`
>
> Once you have finished, reply here:
> **"Conflicts on `<TARGET_BRANCH>` resolved."**
>
> I will then push the port branch and open the Draft PR for this environment, then
> continue with any remaining target branches.

Replace `<TARGET_BRANCH>` with the branch name the script printed.

The agent must **wait** for the user's reply confirming resolution before running any
further git or gh commands.

#### After the user confirms resolution

**Before pushing**, verify that all PR commits are present on the port branch. The conflict
only paused cherry-picking at the first conflicting commit; the remaining commits must be
applied manually if the script exited early.

```bash
# How many commits does the port branch have ahead of the target?
git log origin/<TARGET_BRANCH>..HEAD --oneline

# How many commits does the PR have in total?
gh pr view <PR_NUMBER> --json commits --jq '.commits | length'
```

If the count on the port branch is **less than** the PR commit count, cherry-pick the
missing commits in order before continuing:

```bash
# Apply each missing commit SHA in order (get the full list from Step 3)
git cherry-pick <SHA1> <SHA2> ...
```

If git reports a cherry-pick as empty (already reflected in the target branch), skip it:

```bash
git cherry-pick --skip
```

Once the commit counts match (accounting for legitimately empty/skipped commits), push
the port branch and open the Draft PR manually (the script already exited):

```bash
PORT_BRANCH="port/pr-<PR_NUMBER>-to-<TARGET_BRANCH_SLASHES_REPLACED_WITH_DASHES>"

git push origin "HEAD:refs/heads/${PORT_BRANCH}"

gh pr create \
  --base <TARGET_BRANCH> \
  --head "${PORT_BRANCH}" \
  --title "Port PR #<PR_NUMBER> -> <TARGET_BRANCH> (<ENV_LABEL>)" \
  --body  "Ports the changes from #<PR_NUMBER> into the **<ENV_LABEL>** environment branch \`<TARGET_BRANCH>\`." \
  --draft
```

Then re-run the script with `--resume` / `-Resume` to process any remaining environment branches:

```bash
# macOS / Linux
./scripts/port-pr.sh \
  --pr <PR_NUMBER> \
  --resume <NEXT_TARGET_BRANCH>
```

```powershell
# Windows
./scripts/port-pr.ps1 `
  -PR <PR_NUMBER> `
  -Resume <NEXT_TARGET_BRANCH>
```

The `--resume` flag tells the script to skip all branches that were already processed
successfully and start from the supplied branch.

### Step 6 — Open a Draft PR for each target branch

Opening a Draft PR is the primary outcome of this step — it is how the cherry-picked
commits are handed off to the Deployer. The script does this automatically. If you need
to open one manually, use:

```bash
gh pr create \
  --base releases/X.Y.Z \
  --head port/pr-<PR_NUMBER>-to-releases-X-Y-Z \
  --title "Port PR #<PR_NUMBER> to releases/X.Y.Z (UAT)" \
  --body  "Ports #<PR_NUMBER> to the UAT environment branch." \
  --draft
```

Repeat for PPE (and Prod if different).

> **Why Draft?** Developers do not have permission to create `releases/*` branches directly.
> The Draft PR serves as the vehicle that carries the cherry-picked commits to the Deployer,
> who will then manually create the new `releases/*` branch (with an incremented `<PATCH>`)
> from those commits and close the Draft PR once done.

### Step 7 — Contact a Deployer

Once all Draft port PRs are created and opened, contact a **Deployer** to handle the actual environment
promotion. Present the following URL to the user and ask them to open it in their browser
to find the right person to contact — do not attempt to fetch or open it yourself:

> https://trten.sharepoint.com/sites/TREnterpriseWebPlatform/SitePages/EWP-Deployment.aspx#actors

Also present the following URL to the user and ask them to share it with the Deployer — do not attempt to fetch or open it yourself:

> https://trten.sharepoint.com/sites/TREnterpriseWebPlatform/SitePages/Deploy-Off-Cycle-Releases.aspx

Ask the Deployer to perform these four actions **in order**:

| #   | Action                           | Detail                                                                                                                                                                                                                                                  |
| --- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Create a new `releases/*` branch | Increment the `<PATCH>` of the highest existing patch in the target `<MAJOR>.<MINOR>` series to produce a brand-new branch (e.g. `releases/5.85.18` if `releases/5.85.17` is the current tip). This must be a new branch — never reuse an existing one. |
| 2   | Close the port PR's branch       | Delete the `port/pr-<N>-to-*` branch(es) after they are merged, to keep the remote clean.                                                                                                                                                               |
| 3   | Push the new `releases/*` branch | Push the newly created branch to `origin` so it is visible to Cloud Manager pipelines.                                                                                                                                                                  |
| 4   | Deploy to environments           | Run the appropriate GitHub Actions workflow for each environment:                                                                                                                                                                                       |

**UAT** — [Deploy to UAT](https://github.com/tr/digital_emcm-cloud/actions/workflows/deploy_to_uat.yml)
using the new `releases/*` branch created in step 1.

**PPE / Prod** — [Deploy to PPE](https://github.com/tr/digital_emcm-cloud/actions/workflows/deploy_to_ppe.yml)
using the Prod `releases/*` branch (the new branch from step 1 if Prod was a target,
otherwise the existing resolved Prod branch).

> **If PPE and Prod were on different `releases/*` branches** (i.e. the script detected a
> mismatch after patch resolution and added a separate Prod target), the Deployer must run the
> [Deploy to PPE](https://github.com/tr/digital_emcm-cloud/actions/workflows/deploy_to_ppe.yml)
> workflow a **second time** after the Prod deployment completes, this time using the PPE
> `releases/*` branch, to restore PPE to its own version.

## Checklist

- [ ] Git repository is clean (`git status --porcelain` returns no output)
- [ ] Script fetched deployed versions from UAT, PPE, and Prod version endpoints
- [ ] Script resolved latest patches and logged PPE vs Prod comparison
- [ ] PR commits listed
- [ ] Cherry-picks applied without conflict (or conflicts resolved)
- [ ] Port branches pushed to `origin`
- [ ] Draft port PRs opened against each target branch and shared with a Deployer
- [ ] Deployer reviewed and actioned port PRs
- [ ] User opened the Deployers page and contacted a Deployer
- [ ] Deployer created new `releases/*` branch (patch incremented)
- [ ] Deployer deleted the Draft PR branches
- [ ] Deployer pushed new `releases/*` branch to `origin`
- [ ] Deployer triggered [Deploy to UAT](https://github.com/tr/digital_emcm-cloud/actions/workflows/deploy_to_uat.yml) workflow
- [ ] Deployer triggered [Deploy to PPE](https://github.com/tr/digital_emcm-cloud/actions/workflows/deploy_to_ppe.yml) workflow (Prod branch)
- [ ] _(If PPE != Prod)_ Deployer re-triggered [Deploy to PPE](https://github.com/tr/digital_emcm-cloud/actions/workflows/deploy_to_ppe.yml) workflow (PPE branch) after Prod deployment

## Edge Cases

| Situation                                               | Guidance                                                                                 |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| PR is not yet merged                                    | Either merge it into `release` first, or use it as a closed PR if the commits are already in the branch |
| PR is closed (not merged) and head branch was deleted   | Commits are no longer accessible; the script will exit with an error — the user must provide the SHAs manually |
| PR contains a merge commit with no individual commits   | Cherry-pick the merge commit with `git cherry-pick -m 1 <sha>`                           |
| Target branch is ahead of the PR base                   | Rebase the port branch on the target before opening the PR                               |
| Prod and PPE share the same branch                      | The script detects equality after patch resolution and skips the duplicate automatically |
| Conflict that alters meaning                            | Escalate: do not force-push; open the PR with a conflict-note comment                    |
| Supplied branch is already the latest patch             | Script detects this and proceeds silently without substitution                           |
| No remote branches match the `<MAJOR>.<MINOR>.*` prefix | Script warns and falls back to the supplied branch as-is                                 |
| A `port/pr-<N>-to-*` branch already exists locally      | Script exits immediately and lists every conflicting branch. Delete each with `git branch -D <branch>` before re-running |

## References

- [REFERENCE.md](./REFERENCE.md) — environment branch discovery, Cloud Manager URLs, git-tag heuristics
- [scripts/port-pr.sh](./scripts/port-pr.sh) — automation script (macOS / Linux)
- [scripts/port-pr.ps1](./scripts/port-pr.ps1) — automation script (Windows, PowerShell 7+)
