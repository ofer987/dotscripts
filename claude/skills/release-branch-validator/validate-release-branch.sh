#!/usr/bin/env bash
set -euo pipefail

# ─── Step 1: Identify current branch ─────────────────────────────────────────

branch=$(git rev-parse --abbrev-ref HEAD)

if [[ ! "$branch" =~ ^releases/([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "ERROR: Current branch '${branch}' is not a release branch."
  echo "This script only applies to branches matching releases/<MAJOR>.<MINOR>.<PATCH>."
  echo "Try: git checkout releases/5.80.101"
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
series="${MAJOR}.${MINOR}"

# ─── Step 2: Fetch remote refs and discover existing branches ─────────────────

git fetch origin "refs/heads/releases/${series}.*:refs/remotes/origin/releases/${series}.*" --quiet 2>/dev/null || true

patch_numbers=()
while IFS= read -r n; do
  patch_numbers+=("$n")
done < <(
  git branch -r --list "origin/releases/${series}.*" \
    | sed "s|.*origin/releases/${series}\\.||" \
    | grep -E '^[0-9]+$' \
    | sort -n
)

if [[ ${#patch_numbers[@]} -eq 0 ]]; then
  echo "ERROR: No remote branches found for series releases/${series}.*"
  exit 1
fi

latest_patch="${patch_numbers[${#patch_numbers[@]}-1]}"

# ─── Step 3: Fetch remote tags ────────────────────────────────────────────────

git fetch origin --tags --quiet 2>/dev/null || true

# ─── Step 4: Evaluate checks ─────────────────────────────────────────────────

overall_pass=true

# Latest patch check
latest_check_pass=true
if [[ "$PATCH" -lt "$latest_patch" ]]; then
  latest_check_pass=false
  overall_pass=false
fi

# Release tag check
tag_results=()
missing_count=0
total_count=${#patch_numbers[@]}

for n in "${patch_numbers[@]}"; do
  tag="release-${series}.${n}"
  if git rev-parse --verify "refs/tags/${tag}" >/dev/null 2>&1; then
    tag_results+=("  ${tag}  ✓")
  else
    tag_results+=("  ${tag}  ✗  (missing)")
    ((missing_count++)) || true
    overall_pass=false
  fi
done

# ─── Step 5: Report ───────────────────────────────────────────────────────────

if $overall_pass; then
  echo "Release Branch Validation: PASSED"
else
  echo "Release Branch Validation: FAILED"
fi
echo
echo "Branch:  ${branch}"
echo

if $latest_check_pass; then
  echo "Latest patch check: PASS"
else
  echo "Latest patch check: FAIL"
  echo "  Current : releases/${series}.${PATCH}"
  echo "  Latest  : releases/${series}.${latest_patch}"
  echo "  This branch is not the latest — releases/${series}.${latest_patch} exists on the remote."
fi
echo

if [[ "$missing_count" -eq 0 ]]; then
  echo "Release tag check: ${total_count} tags checked (branches with remote) — all present"
else
  echo "Release tag check: ${missing_count} of ${total_count} tags missing (branches with remote only)"
fi
echo

for line in "${tag_results[@]}"; do
  echo "$line"
done
echo

if $overall_pass; then
  exit 0
else
  exit 1
fi
