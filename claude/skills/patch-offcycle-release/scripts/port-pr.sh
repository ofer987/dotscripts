#!/usr/bin/env bash
# port-pr.sh - Cherry-pick a merged GitHub PR into one or more releases/* branches.
#
# Usage:
#   port-pr.sh --pr <PR_NUMBER> [--uat <branch>] [--ppe <branch>] [--prod <branch>]
#              [--resume <branch>]
#
# Options:
#   --pr      PR number that was merged into `release`           (required)
#   --uat     Override the UAT releases/* branch (auto-discovered if omitted)
#   --ppe     Override the PPE releases/* branch (auto-discovered if omitted)
#   --prod    Override the Prod releases/* branch (auto-discovered if omitted)
#   --resume  Skip to this specific target branch (after conflict resolution)
#
# Branch auto-discovery:
#   When --uat / --ppe / --prod are omitted the script fetches the deployed version
#   from each environment's version endpoint, strips any sub-patch suffix, and
#   constructs the releases/* branch name automatically.  It then resolves the
#   latest patch in that <MAJOR>.<MINOR> series from the remote.
#
#   UAT:  https://author-p163316-e1779207.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json
#   PPE:  https://author-p163316-e1779165.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json
#   Prod: https://author-p163316-e1779099.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json

set -euo pipefail

# -- helpers ------------------------------------------------------------------

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }

# safe_push <port-branch>
#
# Aborts with an error if the destination looks like a releases/* branch
# (belt-and-suspenders guard against accidental pushes to protected
# release branches).
safe_push() {
  local port_branch="$1"

  # Refuse to push if the remote destination would be a releases/* branch.
  if [[ "$port_branch" == releases/* ]]; then
    die "safe_push: refusing to push to '${port_branch}' — destination must not be a releases/* branch."
  fi

  run git push origin "HEAD:refs/heads/${port_branch}"
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found."; }

run() {
  "$@"
}

# -- argument parsing ---------------------------------------------------------

PR_NUMBER=""
UAT_BRANCH=""
PPE_BRANCH=""
PROD_BRANCH=""
RESUME_BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)      PR_NUMBER="$2";    shift 2 ;;
    --uat)     UAT_BRANCH="$2";   shift 2 ;;
    --ppe)     PPE_BRANCH="$2";   shift 2 ;;
    --prod)    PROD_BRANCH="$2";  shift 2 ;;
    --resume)  RESUME_BRANCH="$2"; shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "$PR_NUMBER" ]] || die "--pr is required"

require_cmd git
require_cmd gh
require_cmd curl
require_cmd jq
require_cmd awk
require_cmd head
require_cmd grep
require_cmd sort
require_cmd cut

# -- latest-patch resolver ----------------------------------------------------
#
# Given a branch name like "releases/5.85.7", scan all remote branches that share
# the same <MAJOR>.<MINOR> prefix ("releases/5.85.*") and return the one with the
# highest <PATCH> number.  If the supplied branch IS already the latest, it is
# returned unchanged.  If no remote branches match the prefix at all, the supplied
# branch is returned as-is (and a warning is emitted).
#
# Usage: latest_patch "releases/5.85.7"  ->  "releases/5.85.17"

latest_patch() {
  local input_branch="$1"

  # Extract the version part, e.g. "5.85.7"
  local version="${input_branch#releases/}"

  # Split into major.minor and patch
  local major_minor patch
  major_minor="${version%.*}"   # "5.85"
  patch="${version##*.}"        # "7"

  # List all remote branches matching releases/<MAJOR>.<MINOR>.*
  # git branch -r output lines look like "  origin/releases/5.85.17"
  local prefix="releases/${major_minor}."
  local best_patch="$patch"
  local best_branch="$input_branch"

  while IFS= read -r line; do
    # Strip leading whitespace and the "origin/" remote prefix
    local remote_branch
    remote_branch="${line#"${line%%[! ]*}"}"   # trim leading spaces
    remote_branch="${remote_branch#origin/}"    # strip "origin/"

    [[ "$remote_branch" == "${prefix}"* ]] || continue

    local candidate_patch="${remote_branch#"${prefix}"}"

    # Accept only pure numeric patch values
    [[ "$candidate_patch" =~ ^[0-9]+$ ]] || continue

    if (( candidate_patch > best_patch )); then
      best_patch="$candidate_patch"
      best_branch="releases/${major_minor}.${candidate_patch}"
    fi
  done < <(git branch -r)

  if [[ "$best_branch" != "$input_branch" ]]; then
    # warn already writes to stderr, safe inside command substitution
    warn "Patch upgrade: '${input_branch}' -> '${best_branch}' (latest in ${major_minor}.x series)"
  else
    echo "==> ${input_branch} is already the latest patch in ${major_minor}.x series" >&2
  fi

  echo "$best_branch"
}

# -- environment version discovery --------------------------------------------
#
# Fetches the deployed version string from an AEM environment's version endpoint
# and returns only the first three dot-separated segments (MAJOR.MINOR.PATCH),
# discarding any sub-patch suffix (e.g. "5.83.86.2026_0724_..." -> "5.83.86").
#
# Usage: fetch_env_version <url> <env-label>

readonly UAT_VERSION_URL="https://author-p163316-e1779207.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json"
readonly PPE_VERSION_URL="https://author-p163316-e1779165.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json"
readonly PROD_VERSION_URL="https://author-p163316-e1779099.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json"

fetch_env_version() {
  local url="$1"
  local label="$2"

  local raw
  raw=$(curl -sf "$url") || die "Failed to fetch version for ${label} from ${url}"

  # Extract version string: try jq first, fall back to grep for a bare version token
  local version=""
  if command -v jq >/dev/null 2>&1; then
    version=$(printf '%s' "$raw" | jq -r '.version // empty' 2>/dev/null || true)
  fi
  if [[ -z "$version" ]]; then
    version=$(printf '%s' "$raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^"]*' | head -1 || true)
  fi

  [[ -n "$version" ]] || die "Could not parse version for ${label} from response: ${raw}"

  # Keep only MAJOR.MINOR.PATCH - discard everything from the 4th dot onward
  local trimmed
  trimmed=$(printf '%s' "$version" | cut -d. -f1-3)

  # Write to stderr so it does not corrupt the captured return value
  echo "==> Discovered ${label} version: ${version} -> using ${trimmed}" >&2
  echo "$trimmed"
}

# -- preflight ----------------------------------------------------------------

# Check for unmerged files or uncommitted changes before touching any branches.
# Cherry-picking onto a dirty working tree will fail or produce incorrect results.
UNMERGED=$(git ls-files --unmerged)
if [[ -n "$UNMERGED" ]]; then
  echo ""
  echo "ERROR: Your working tree has unmerged files. Resolve them before running this script." >&2
  echo "" >&2
  echo "Please review the following files:" >&2
  git ls-files --unmerged | awk '{print "  " $NF}' | sort -u >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  1. Resolve conflicts, then: git add <files> && git commit" >&2
  echo "  2. Abort any in-progress cherry-pick/merge: git cherry-pick --abort  OR  git merge --abort" >&2
  echo "  3. Discard changes (destructive): git checkout -- <files>" >&2
  exit 1
fi

# Check for modified-but-not-staged files specifically (working tree differs from index).
UNSTAGED=$(git diff --name-only)
if [[ -n "$UNSTAGED" ]]; then
  echo "" >&2
  echo "ERROR: You have modified files that have not been staged:" >&2
  echo "" >&2
  while IFS= read -r f; do
    echo "  $f" >&2
  done <<< "$UNSTAGED"
  echo "" >&2
  echo "Options:" >&2
  echo "  1. Stage and commit:      git add <files> && git commit -m 'WIP'" >&2
  echo "  2. Stash (recommended):   git stash push -u -m 'stash before port'" >&2
  echo "  3. Discard (destructive): git checkout -- <files>" >&2
  exit 1
fi

# Check for remaining uncommitted changes (staged but not committed).
# Untracked files (??) are intentionally excluded — they cannot affect cherry-picks.
# The `|| true` prevents grep's non-zero exit when all lines are filtered (pipefail-safe).
DIRTY=$(git status --porcelain | { grep -v '^??' || true; })
if [[ -n "$DIRTY" ]]; then
  echo "" >&2
  echo "ERROR: Your working tree has uncommitted changes. Commit or stash them before running this script." >&2
  echo "" >&2
  git status --short >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  1. Commit:                git add -A && git commit -m 'WIP'" >&2
  echo "  2. Stash (recommended):   git stash push -u -m 'stash before port'" >&2
  echo "  3. Discard (destructive): git checkout -- . && git clean -fd" >&2
  exit 1
fi

info "Verifying PR #${PR_NUMBER}..."
PR_JSON=$(gh pr view "$PR_NUMBER" --json state,baseRefName)
PR_STATE=$(echo "$PR_JSON" | jq -r '.state')
PR_BASE=$(echo "$PR_JSON" | jq -r '.baseRefName')
[[ "$PR_STATE" == "MERGED" || "$PR_STATE" == "CLOSED" ]] || die "PR #${PR_NUMBER} must be merged or closed to be ported (state: ${PR_STATE})."
[[ "$PR_BASE" == "release" ]] || die "PR #${PR_NUMBER} is not targeting 'release' (base branch: ${PR_BASE}). Only PRs targeting 'release' can be ported."

info "Fetching latest remote state..."
run git fetch --all --prune

# -- resolve latest patch per environment -------------------------------------

info "Discovering deployed versions..."
if [[ -z "$UAT_BRANCH" ]]; then
  UAT_VERSION=$(fetch_env_version "$UAT_VERSION_URL" "UAT")
  UAT_BRANCH="releases/${UAT_VERSION}"
fi
if [[ -z "$PPE_BRANCH" ]]; then
  PPE_VERSION=$(fetch_env_version "$PPE_VERSION_URL" "PPE")
  PPE_BRANCH="releases/${PPE_VERSION}"
fi
if [[ -z "$PROD_BRANCH" ]]; then
  PROD_VERSION=$(fetch_env_version "$PROD_VERSION_URL" "Prod")
  PROD_BRANCH="releases/${PROD_VERSION}"
fi

info "Resolving latest patch in each MAJOR.MINOR series..."
UAT_BRANCH=$(latest_patch  "$UAT_BRANCH")
PPE_BRANCH=$(latest_patch  "$PPE_BRANCH")
PROD_BRANCH=$(latest_patch "$PROD_BRANCH")

# -- collect commits ----------------------------------------------------------

COMMITS=()
while IFS= read -r sha; do
  [[ -n "$sha" ]] && COMMITS+=("$sha")
done < <(gh pr view "$PR_NUMBER" --json commits --jq '.commits[].oid')

if [[ ${#COMMITS[@]} -eq 0 ]]; then
  if [[ "$PR_STATE" == "MERGED" ]]; then
    warn "No individual commits found; falling back to merge commit with -m 1."
    MERGE_SHA=$(gh pr view "$PR_NUMBER" --json mergeCommit --jq '.mergeCommit.oid')
    [[ -n "$MERGE_SHA" ]] || die "Could not determine merge commit SHA for PR #${PR_NUMBER}."
    COMMITS=("${MERGE_SHA}")
    USE_MERGE_PARENT=true
  else
    die "No commits found for closed PR #${PR_NUMBER}. The head branch may have been deleted."
  fi
else
  USE_MERGE_PARENT=false
fi

info "Commits to port (${#COMMITS[@]}):"
for sha in "${COMMITS[@]}"; do
  echo "  ${sha}"
done

# -- build target list --------------------------------------------------------
# Use parallel indexed arrays (bash 3.2-compatible; no associative arrays)

ENV_LABELS=()
ENV_BRANCHES=()

ENV_LABELS+=("UAT"); ENV_BRANCHES+=("$UAT_BRANCH")
ENV_LABELS+=("PPE"); ENV_BRANCHES+=("$PPE_BRANCH")

PPE_COVERS_PROD=false
if [[ "$PROD_BRANCH" == "$PPE_BRANCH" ]]; then
  info "Prod (${PROD_BRANCH}) == PPE (${PPE_BRANCH}) after patch resolution - skipping duplicate Prod port."
  PPE_COVERS_PROD=true
else
  info "Prod (${PROD_BRANCH}) differs from PPE (${PPE_BRANCH}) - adding separate Prod target."
  ENV_LABELS+=("Prod"); ENV_BRANCHES+=("$PROD_BRANCH")
fi

# -- port-branch collision check ----------------------------------------------
# Fail fast if ANY local port branch already exists for this PR across ALL
# target environments.  The user must delete stale branches manually so there
# is no risk of accidentally reusing or overwriting prior work.

EXISTING_PORT_BRANCHES=()
for i in "${!ENV_LABELS[@]}"; do
  _pb="port/pr-${PR_NUMBER}-to-${ENV_BRANCHES[$i]//\//-}"
  if git show-ref --verify --quiet "refs/heads/${_pb}"; then
    EXISTING_PORT_BRANCHES+=("$_pb")
  fi
done

if [[ ${#EXISTING_PORT_BRANCHES[@]} -gt 0 ]]; then
  echo "" >&2
  echo "ERROR: The following local port branch(es) already exist for PR #${PR_NUMBER}:" >&2
  echo "" >&2
  for b in "${EXISTING_PORT_BRANCHES[@]}"; do
    echo "  ${b}" >&2
  done
  echo "" >&2
  echo "Please delete them manually before running this script again:" >&2
  echo "" >&2
  for b in "${EXISTING_PORT_BRANCHES[@]}"; do
    echo "  git branch -D ${b}" >&2
  done
  echo "" >&2
  exit 1
fi

# -- cherry-pick loop ---------------------------------------------------------

REPO_URL=$(gh repo view --json url --jq '.url')
SKIPPING=false
[[ -n "$RESUME_BRANCH" ]] && SKIPPING=true

for i in "${!ENV_LABELS[@]}"; do
  env_label="${ENV_LABELS[$i]}"
  TARGET_BRANCH="${ENV_BRANCHES[$i]}"

  if [[ "$SKIPPING" == "true" ]]; then
    if [[ "$TARGET_BRANCH" == "$RESUME_BRANCH" ]]; then
      SKIPPING=false
    else
      info "Skipping ${env_label} (${TARGET_BRANCH}) - resuming at ${RESUME_BRANCH}."
      continue
    fi
  fi

  PORT_BRANCH="port/pr-${PR_NUMBER}-to-${TARGET_BRANCH//\//-}"

  info "--------------------------------------------------"
  info "Environment : ${env_label}"
  info "Target      : ${TARGET_BRANCH}"
  info "Port branch : ${PORT_BRANCH}"
  info "--------------------------------------------------"

  # Check out the port branch from the remote target.
  # --no-track ensures no upstream is set, so a plain `git push` can never
  # silently resolve to a releases/* branch — every push in this script uses
  # an explicit refspec via safe_push().
  run git checkout --no-track -b "$PORT_BRANCH" "origin/${TARGET_BRANCH}"

  # Cherry-pick
  CHERRY_PICK_FAILED=false
  FAILED_IDX=0
  COMMIT_IDX=0
  for sha in "${COMMITS[@]}"; do
    if [[ "$USE_MERGE_PARENT" == "true" ]]; then
      run git cherry-pick -m 1 "$sha" || pick_exit=$?
    else
      run git cherry-pick "$sha" || pick_exit=$?
    fi

    if [[ "${pick_exit:-0}" -ne 0 ]]; then
      # Distinguish an empty cherry-pick (change already applied) from a real
      # conflict.  git ls-files --unmerged lists files with conflict markers;
      # an empty cherry-pick leaves this list empty even though git paused.
      if [[ -z "$(git ls-files --unmerged)" ]]; then
        warn "Commit ${sha} is already present in ${TARGET_BRANCH} - skipping."
        run git cherry-pick --skip
      else
        CHERRY_PICK_FAILED=true
        FAILED_IDX=$COMMIT_IDX
        break
      fi
    fi
    pick_exit=0
    (( COMMIT_IDX++ )) || true
  done

  if [[ "$CHERRY_PICK_FAILED" == "true" ]]; then
    # Commits that still need to be applied after the conflict is resolved.
    REMAINING_AFTER_CONFLICT=("${COMMITS[@]:$((FAILED_IDX + 1))}")

    echo ""
    echo "======================================================================" >&2
    echo "ACTION REQUIRED — Cherry-pick conflict on ${env_label} (${TARGET_BRANCH})" >&2
    echo "======================================================================" >&2
    echo "" >&2
    echo "You must resolve the conflicts manually before this script can continue." >&2
    echo "" >&2
    echo "Steps:" >&2
    echo "  1. git status          (see which files have conflict markers)" >&2
    echo "  2. git diff            (review each conflict in detail)" >&2
    echo "  3. Edit each conflicted file and fix the <<<<<<<  =======  >>>>>>> markers" >&2
    echo "  4. git add <resolved-files>" >&2
    echo "  5. git cherry-pick --continue" >&2
    if [[ ${#REMAINING_AFTER_CONFLICT[@]} -gt 0 ]]; then
    echo "" >&2
    echo "  The following ${#REMAINING_AFTER_CONFLICT[@]} commit(s) come after the conflict and must" >&2
    echo "  also be cherry-picked before pushing:" >&2
    echo "" >&2
    echo "  6. git cherry-pick ${REMAINING_AFTER_CONFLICT[*]}" >&2
    echo "     (skip any that are empty: git cherry-pick --skip)" >&2
    echo "" >&2
    echo "  7. Verify all commits are on the port branch:" >&2
    echo "     git log origin/${TARGET_BRANCH}..HEAD --oneline" >&2
    echo "" >&2
    echo "  8. git push origin \"HEAD:refs/heads/${PORT_BRANCH}\"" >&2
    else
    echo "  6. git push origin \"HEAD:refs/heads/${PORT_BRANCH}\"" >&2
    fi
    echo "" >&2
    echo "After completing those steps, re-run this script with:" >&2
    echo "  --resume ${TARGET_BRANCH}" >&2
    echo "" >&2
    echo "If running via the agent, reply to the agent once conflicts are resolved." >&2
    echo "======================================================================" >&2
    exit 1
  fi

  # If every commit was already present the port branch is identical to the
  # target — nothing to port for this environment.
  AHEAD=$(git rev-list --count "origin/${TARGET_BRANCH}..HEAD")
  if [[ "$AHEAD" -eq 0 ]]; then
    info "All commits already present in ${TARGET_BRANCH} - no port needed for ${env_label}."
    run git checkout -
    run git branch -D "$PORT_BRANCH"
    continue
  fi

  # Push using safe_push, which uses an explicit refspec and refuses to push
  # to any releases/* destination.
  safe_push "$PORT_BRANCH"

  # Print compare URL
  COMPARE_URL="${REPO_URL}/compare/${TARGET_BRANCH}...${PORT_BRANCH}?expand=1"
  echo ""
  echo "OK: Port branch pushed. Open a PR at:"
  echo "  ${COMPARE_URL}"
  echo ""

  # Open a Draft PR - this is the primary handoff mechanism to the Deployer.
  # Developers cannot push directly to releases/* branches, so the Draft PR
  # carries the cherry-picked commits for the Deployer to create the new branch.
  if [[ "$env_label" == "PPE" && "$PPE_COVERS_PROD" == "true" ]]; then
    PR_TITLE="Port PR #${PR_NUMBER} -> ${TARGET_BRANCH} (PPE + Prod)"
    PR_BODY="Ports the changes from #${PR_NUMBER} into the **PPE and Prod** environment branch \`${TARGET_BRANCH}\`.

> **Note:** PPE and Prod are currently on the same branch (\`${TARGET_BRANCH}\`). This PR covers both environments."
  else
    PR_TITLE="Port PR #${PR_NUMBER} -> ${TARGET_BRANCH} (${env_label})"
    PR_BODY="Ports the changes from #${PR_NUMBER} into the **${env_label}** environment branch \`${TARGET_BRANCH}\`."
  fi

  run gh pr create \
    --base "$TARGET_BRANCH" \
    --head "$PORT_BRANCH" \
    --title "$PR_TITLE" \
    --body  "$PR_BODY" \
    --draft
done

info "Done. All environment branches processed."
