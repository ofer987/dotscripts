---
name: prune-local-branches
description: Deletes local git branches whose upstream branch has been removed from the remote. Use when the user wants to clean up stale local branches, mentions pruning, "gone branches", branches deleted on GitHub, or wants to remove local branches that no longer exist on the remote.
---

# Prune Local Branches

## Steps

1. Run the detection script:

   ```
   bash .claude/skills/prune-local-branches/scripts/list-gone.sh
   ```

2. If no stale branches are found, report that and stop.

3. Show the list to the user and ask for confirmation before deleting anything.

4. For each branch, attempt a safe delete:
   ```
   git branch -d <branch>
   ```
   If it fails due to unmerged commits, ask the user before force-deleting:
   ```
   git branch -D <branch>
   ```

## Rules

- Never delete the current branch (`git branch --show-current`).
- Never delete `main` or `master` regardless of upstream status.
- Always confirm with the user before deleting.
