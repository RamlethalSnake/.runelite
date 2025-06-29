#!/bin/bash

set -e
set -o pipefail

# Step 0: Clean previous workspace
echo "🧹 Cleaning up old .sync-tmp-debug and pruning stale worktrees..."
rm -rf ".sync-tmp-debug"
git worktree prune

echo "🔧 Starting bulletproof sync from master to individual branches..."

# Step 1: Commit changes on master
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Step 2: Fetch all remotes
git fetch origin

# Step 3: Branch-folder mapping
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

WORKTREE_BASE=".sync-tmp-debug"
mkdir -p "$WORKTREE_BASE"
FAILED_BRANCHES=()

# Step 4: Loop through branches with fault isolation
for branch in customhovers dropsounds notifications engineersounds ResourceCustom minimal; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"

  echo ""
  echo "🔄 Syncing [$branch] with folders: $folders"

  {
    # Check or create local branch
    if git show-ref --quiet --verify "refs/heads/$branch"; then
      echo "🔁 Local branch [$branch] exists."
    else
      echo "🛠️ Creating local branch [$branch] from origin/$branch"
      git branch "$branch" "origin/$branch" || {
        echo "❌ Failed to create branch [$branch] — skipping."
        FAILED_BRANCHES+=("$branch")
        exit 0
      }
    fi

    # Force-remove old worktree if needed
    if [ -d "$worktree_path" ]; then
      echo "🧹 Removing worktree dir for [$branch]"
      git worktree remove --force "$worktree_path" || rm -rf "$worktree_path"
    fi

    git worktree add --quiet "$worktree_path" "$branch"

    # Sync folders via rsync
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
        echo "✅ [$branch] synced and pushed."
      fi
    )
  } || {
    echo "❌ Sync for [$branch] failed — moving to next."
    FAILED_BRANCHES+=("$branch")
  }
done

# Step 5: Final cleanup
echo ""
echo "🧼 Final cleanup of temp folders..."
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

if [ ${#FAILED_BRANCHES[@]} -eq 0 ]; then
  echo "🎉 All branches synced successfully!"
else
  echo "⚠️ Some branches failed:"
  printf ' - %s\n' "${FAILED_BRANCHES[@]}"
fi