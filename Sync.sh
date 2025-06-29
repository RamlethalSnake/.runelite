#!/bin/bash

set -e
set -o pipefail

echo "🔧 Starting verbose sync from master to individual branches..."

# Step 1: Commit any outstanding changes to master
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Step 2: Fetch all remote branches to ensure visibility
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

# Step 4: Create temp worktree directory
WORKTREE_BASE=".sync-tmp-debug"
mkdir -p "$WORKTREE_BASE"

# Step 5: Process each branch
for branch in "${!branch_folders[@]}"; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"

  echo ""
  echo "🔄 Syncing [$branch] with folders: $folders"

  # Create local tracking branch if it doesn't exist
  if ! git show-ref --quiet --verify "refs/heads/$branch"; then
    echo "🛠️ Creating local branch [$branch] from origin/$branch"
    git branch "$branch" "origin/$branch"
  fi

  # Ensure worktree is clean
  git worktree remove --force "$worktree_path" 2>/dev/null || true

  # Create worktree from local branch
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

# Step 6: Clean up all temporary worktrees
echo ""
echo "🧹 Cleaning up .sync-tmp-debug"
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

echo "🎉 Full sync complete! All mapped branches now reflect the latest folder state from master."