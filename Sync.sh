#!/bin/bash

set -e
set -o pipefail

echo "🔧 Starting clean sync from [master] to individual folder-branches..."

# Step 1: Update master branch with latest changes
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Step 2: Fetch all remote branches
git fetch origin

# Step 3: Define folder-to-branch mapping
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

# Step 4: Set up a temp directory for clean worktrees
WORKTREE_BASE=".sync-tmp"
mkdir -p "$WORKTREE_BASE"

# Step 5: Loop through each branch and sync its designated folder(s)
for branch in "${!branch_folders[@]}"; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"

  echo ""
  echo "🔄 Syncing [$branch]..."

  git worktree remove --force "$worktree_path" 2>/dev/null || true
  git worktree add --quiet "$worktree_path" "origin/$branch"

  for folder in $folders; do
    echo "📁 Syncing [$folder] → [$branch]"
    rsync -a --delete "$folder" "$worktree_path/"
  done

  (
    cd "$worktree_path"
    git add $folders .gitignore || true
    git commit -m "Force-sync: replace $folders from master" || echo "⚠️ [$branch] Nothing to commit."
    git push origin HEAD:"$branch"
    echo "✅ [$branch] updated."
  )
done

# Step 6: Cleanup
echo ""
echo "🧹 Cleaning up worktrees..."
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

echo "🎉 All branches successfully synced from master folder state."