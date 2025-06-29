#!/bin/bash

set -e
set -o pipefail

# Step 0: Clean up any previous temp workspace
echo "🧹 Removing old .sync-tmp-debug directory and pruning orphaned worktrees..."
rm -rf ".sync-tmp-debug"
git worktree prune

echo "🔧 Starting verbose sync from master to individual branches..."

# Step 1: Commit any outstanding changes to master
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Step 2: Fetch all remote branches to ensure they're visible
git fetch origin

# Step 3: Define mapping of branch → folders
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

# Step 4: Create clean temp workspace
WORKTREE_BASE=".sync-tmp-debug"
mkdir -p "$WORKTREE_BASE"

# Step 5: Loop through and sync each target branch
for branch in "${!branch_folders[@]}"; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"

  echo ""
  echo "🔄 Syncing [$branch] with folders: $folders"

  # Ensure local tracking branch exists
  if ! git show-ref --quiet --verify "refs/heads/$branch"; then
    echo "🛠️ Creating local branch [$branch] from origin/$branch"
    git branch "$branch" "origin/$branch"
  fi

  git worktree remove --force "$worktree_path" 2>/dev/null || true
  git worktree add --quiet "$worktree_path" "$branch"

  for folder in $folders; do
    echo "📁 Overwriting [$folder] from master into [$branch]"
    rsync -a --delete "$folder" "$worktree_path/"
  done

  (
    cd "$worktree_path"
    git add $folders .gitignore || true

    echo "📦 Git status for [$branch]:"
    git status --short || true

    echo "📄 Git diff summary:"
    git diff --cached --name-status || true

    if git diff --cached --quiet; then
      echo "⚠️ [$branch] No changes detected — skipping commit."
    else
      git commit -m "Force-sync: replace $folders from master"
      git push origin HEAD:"$branch"
      echo "✅ [$branch] updated and pushed."
    fi
  )
done

# Step 6: Cleanup workspace
echo ""
echo "🧹 Cleaning up .sync-tmp-debug"
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

echo "🎉 Full sync complete! All branches reflect master folder state."