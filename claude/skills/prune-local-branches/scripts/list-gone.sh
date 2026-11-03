#!/usr/bin/env bash
set -euo pipefail

echo "Fetching and pruning remote-tracking refs..."
git fetch --prune

gone=$(git branch -vv | awk '/: gone\]/ { print ($1 == "*") ? $2 : $1 }')

if [ -z "$gone" ]; then
  echo "No stale local branches found."

  exit 0
fi

echo ""
echo "Local branches whose upstream has been deleted on the remote:"
echo "$gone" | sed 's/^/  /'
