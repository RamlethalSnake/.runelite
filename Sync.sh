#!/bin/bash

set -e
set -o pipefail

echo "🔧 Starting verbose sync from master to individual branches..."

# Step 1: Commit changes from master
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Step 2: Fetch all remote branches
git fetch origin

# Step 3: Define branch → folder(s) mapping
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

# Step 4: Set up temporary workspace
WORKTREE_BASE=".sync-tmp-debug"
mkdir -p "$WORKTREE_BASE"

# Step 5: Process each branch
for branch in "${!branch_folders[@]}"; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"
  echo ""
  echo "🔄 Syncing [$branch] with folders: $folders"

  git worktree remove --force "$worktree_path" 2>/dev/null || true
  git worktree add --quiet "$worktree_path" "origin/$branch"

  for folder in $folders; do
    echo "📁 Overwriting [$folder] in [$branch]"
    rsync -a --delete "$folder" "$worktree_path/"
  done

  (
    cd "$worktree_path"
    echo "📦 Staging changes for [$branch]..."
    git add $folders .gitignore || true

    echo "🔍 Git status before commit:"
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

# Step 6: Cleanup
echo ""
echo "🧹 Cleaning up worktrees..."
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

echo "🎉 Sync complete! Debug logs displayed above."