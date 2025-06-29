#!/bin/bash

set -e
set -o pipefail

echo "🔧 Starting clean sync from [master] to individual folder-branches..."

# Step 1: Update master branch with latest edits
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master updated."

# Step 2: Define folder-branch mapping
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

# Step 3: Set up temporary workspace
WORKTREE_BASE=".sync-tmp"
mkdir -p "$WORKTREE_BASE"

# Step 4: Sync each branch from master’s working directory
for branch in "${!branch_folders[@]}"; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"

  echo ""
  echo "🔄 Syncing [$branch]..."

  git worktree remove --force "$worktree_path" 2>/dev/null || true
  git worktree add --quiet "$worktree_path" "$branch"

  for folder in $folders; do
    echo "📁 Syncing folder [$folder] → branch [$branch]"

    rsync -a --delete "$folder" "$worktree_path/"
  done

  (
    cd "$worktree_path"
    git add $folders .gitignore || true
    git commit -m "Force-sync: replace $folders from master" || echo "⚠️ [$branch] No changes to commit."
    git push origin "$branch"
    echo "✅ [$branch] updated."
  )
done

# Step 5: Clean up
echo ""
echo "🧹 Cleaning temporary worktrees..."
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

echo "🎉 All branches successfully synced from master."