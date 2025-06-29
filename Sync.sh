#!/bin/bash

set -e
set -o pipefail

echo "🔧 Starting force sync: replacing branch folders with master versions..."

# --- Sync master first ---
git checkout master

# Stage any updates (including changed binaries)
git add -u
git add -A  # force pick up deletes or renames
git add notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/ .gitignore sync.sh || true

git commit -m "Force-sync: commit all tracked folder changes" || echo "✅ [master] No changes to commit."
git push origin master
echo "🚀 [master] Pushed all changes."

# Define branch-folder mapping
declare -A branch_folders=(
  [customhovers]="customitemhovers/"
  [dropsounds]="drop-sounds/"
  [notifications]="notifications/"
  [engineersounds]="c-engineer-sounds/"
  [ResourceCustom]="ResourceCustom/"
  [minimal]="notifications/ drop-sounds/ customitemhovers/ c-engineer-sounds/ ResourceCustom/"
)

# --- Replace folders in each branch ---
for branch in "${!branch_folders[@]}"; do
  echo ""
  echo "🔄 Forcing [$branch] to match master folders..."

  if git show-ref --verify --quiet refs/heads/$branch; then
    git checkout "$branch"
    git pull origin "$branch"
  else
    echo "❗ Branch '$branch' doesn't exist — skipping."
    continue
  fi

  folders="${branch_folders[$branch]}"
  echo "🧨 Overwriting content: $folders"
  git checkout master -- $folders

  git add $folders .gitignore
  git commit -m "Force-sync: overwrite $folders from master" || echo "⚠️ [$branch] Nothing to commit."
  git push origin "$branch"
  echo "🚀 [$branch] Updated with forced content."
done

git checkout master
echo ""
echo "🎉 Force sync complete. All branches updated with master folder content."