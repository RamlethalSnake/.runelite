#!/bin/bash

set -e
set -o pipefail

echo "🔧 Starting clean sync from master to each folder-branch..."

# Commit changes from master first
git checkout master
git pull origin master

# Stage all changes in master (safe to add/remove/rename within 28 folders)
git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Map branch names to the folders they should own
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

# Create temp sync directory
WORKTREE_BASE=".sync-tmp"
mkdir -p "$WORKTREE_BASE"

# Sync each branch folder from master
for branch in "${!branch_folders[@]}"; do
  folder_paths="${branch_folders[$branch]}"
  path="$WORKTREE_BASE/$branch"

  echo ""
  echo "🔄 Syncing branch [$branch]..."

  # Remove existing worktree if it exists
  git worktree remove --force "$path" 2>/dev/null || true

  # Add branch into isolated worktree folder
  git worktree add --quiet "$path" "$branch"

  cd "$path"

  # Replace only designated folders from master
  for folder in $folder_paths; do
    git checkout master -- "$folder"
  done

  git add $folder_paths .gitignore || true
  git commit -m "Sync: update $folder_paths from master" || echo "⚠️ No changes to commit in [$branch]."
  git push origin "$branch"
  echo "✅ [$branch] synced with master."

  cd - >/dev/null
done

echo ""
echo "🧹 Cleaning up worktrees..."
rm -rf "$WORKTREE_BASE"

git worktree prune
git checkout master

echo "🎉 All branches synced cleanly from master folder state."