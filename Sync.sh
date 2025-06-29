#!/bin/bash

set -e
set -o pipefail

# ✅ Check for rsync availability
if ! command -v rsync >/dev/null 2>&1; then
  echo "❌ Error: rsync not found in PATH. Please install or adjust your environment."
  exit 1
fi

# Step 0: Cleanup
echo "🧹 Cleaning up old worktrees..."
rm -rf ".sync-tmp-debug"
git worktree prune

# Prepare log directory
mkdir -p ".sync-logs"
log_ts=$(date +"%Y-%m-%d %H:%M:%S")

echo "🔧 Starting bulletproof sync from master to individual branches..."

# Step 1: Commit changes on master
git checkout master
git pull origin master

git add -A
git commit -m "Sync: staged updates from master" || echo "✅ No changes to commit in master."
git push origin master
echo "🚀 Master branch updated."

# Step 2: Fetch latest remotes
git fetch origin

# Step 3: Branch-folder mapping
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [cengineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

WORKTREE_BASE=".sync-tmp-debug"
mkdir -p "$WORKTREE_BASE"
FAILED_BRANCHES=()

# Step 4: Per-branch sync loop with command tracing
for branch in customhovers dropsounds notifications cengineersounds ResourceCustom minimal; do
  folders="${branch_folders[$branch]}"
  worktree_path="$WORKTREE_BASE/$branch"
  log_file=".sync-logs/$branch.log"

  echo ""
  echo "🔄 Syncing [$branch] with folders: $folders"
  echo "🔄 [$log_ts] Starting sync for [$branch]" > "$log_file"
  echo "Folders: $folders" >> "$log_file"

  {
    set -x  # 🔍 Begin command trace for this branch

    # Ensure local branch exists
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

    # Remove prior worktree if needed
    if [ -d "$worktree_path" ]; then
      echo "🧹 Removing existing worktree dir for [$branch]"
      git worktree remove --force "$worktree_path" || rm -rf "$worktree_path"
    fi

    git worktree add --quiet "$worktree_path" "$branch"

    IFS=' ' read -r -a folder_array <<< "$folders"

    for folder in "${folder_array[@]}"; do
      echo "📁 Syncing [$folder] into [$branch]"
      rsync -a --delete "$folder" "$worktree_path/"
    done

    (
      cd "$worktree_path"

      echo "" >> "$log_file"
      echo "🔎 Synced folder contents:" >> "$log_file"
      for folder in "${folder_array[@]}"; do
        echo "🗂 $folder" >> "$log_file"
        ls -lR "$folder" >> "$log_file" 2>&1 || echo "⚠️ Folder [$folder] missing after rsync." >> "$log_file"
      done

      git add "${folder_array[@]}" .gitignore >> "$log_file" 2>&1 || true

      echo "" >> "$log_file"
      echo "📦 Git status:" >> "$log_file"
      git status --short >> "$log_file" 2>&1 || true

      echo "📄 Git diff:" >> "$log_file"
      git diff --cached --name-status >> "$log_file" 2>&1 || true

      if git diff --cached --quiet; then
        echo "⚠️ [$branch] No changes to commit."
        echo "⚠️ No changes to commit." >> "$log_file"
      else
        git commit -m "Force-sync: replace $folders from master" >> "$log_file" 2>&1
        git push origin HEAD:"$branch" >> "$log_file" 2>&1
        echo "✅ [$branch] synced and pushed."
        echo "✅ Sync complete for [$branch]" >> "$log_file"
      fi
    )

    set +x  # 🔚 End command trace
  } || {
    echo "❌ Sync for [$branch] failed — see $log_file"
    echo "❌ Error syncing branch." >> "$log_file"
    FAILED_BRANCHES+=("$branch")
  }
done

# Step 5: Final cleanup
echo ""
echo "🧼 Final cleanup of temp worktrees..."
rm -rf "$WORKTREE_BASE"
git worktree prune
git checkout master

if [ ${#FAILED_BRANCHES[@]} -eq 0 ]; then
  echo "🎉 All branches synced successfully!"
else
  echo "⚠️ Some branches failed:"
  printf ' - %s\n' "${FAILED_BRANCHES[@]}"
fi