#!/bin/bash

set -e
set -o pipefail

# Step 0: Clean up previous workspace
echo "🧹 Removing leftover .sync-tmp-debug and pruning old worktrees..."
rm -rf ".sync-tmp-debug"
git worktree prune

echo "🔧 Starting verbose sync from master to individual branches..."

# Step 1: Commit any changes on master
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Step 2: Fetch all branches from origin
git fetch origin

# Step 3: Map each branch to its folder(s)
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

# Step 4: Worktree sync for each branch
WORKTREE_BASE=".sync-tmp-debug"
mkdir -p "$WORKTREE_BASE"

for branch in customhovers dropsounds notifications engineersounds ResourceCustom minimal; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"

  echo ""
  echo "🔄 Syncing [$branch] with folders: $folders"

  # Ensure local branch exists
  if git show-ref --quiet --verify "refs/heads/$branch"; then
    echo "🔁 Local branch [$branch] already exists — continuing."
  else
    echo "🛠️ Creating local tracking branch [$branch] from origin/$branch"
    git branch "$branch" "origin/$branch" || echo "⚠️ Failed to create branch [$branch]."
  fi

  # Remove existing worktree safely
  if [ -d "$worktree_path" ]; then
    echo "🧹 Removing existing worktree for [$branch]"
    git worktree remove --force "$worktree_path" || rm -rf "$worktree_path"
  fi

  # Add worktree
  git worktree add --quiet "$worktree_path" "$branch"

  # Sync folders using rsync
  for folder in $folders; do
    echo "📁 Syncing [$folder] into [$branch]"
    rsync -a --delete "$folder" "$worktree_path/"
  done

  (
    cd "$worktree_path"
    git add $folders .gitignore || true

    echo "📦 Git status for [$branch]:"
    git status --short || true

    echo "📄 Git diff:"
    git diff --cached --name-status || true

    if git diff --cached --quiet; then
      echo "⚠️ [$branch] No changes to commit."
    else
      git commit -m "Force-sync: replace $folders from master"
      git push origin HEAD:"$branch"
      echo "✅ [$branch] updated and pushed."
    fi
  )
done

# Step 5: Final cleanup
echo ""
echo "🧼 Cleaning up worktrees..."
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

echo "🎉 All branches synced successfully from master!"