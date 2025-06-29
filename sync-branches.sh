#!/bin/bash

set -e  # Exit on any error
set -o pipefail

# Enable debug print
echo "🔧 Starting full sync with debugging enabled..."

# Commit changes on master if needed
echo "📦 [master] Staging and committing changes..."
git checkout master
git add .
git commit -m "Auto-commit: sync to branches" || echo "✅ [master] No changes to commit."
git push origin master
echo "🚀 [master] Pushed latest changes."

# Define target branches
branches=(
  customhovers
  dropsounds
  notifications
  engineersounds
  ResourceCustom
  minimal
)

# Loop through branches
for branch in "${branches[@]}"
do
  echo ""
  echo "🔄 Syncing [$branch]..."

  # Try checkout
  if git show-ref --verify --quiet refs/heads/$branch; then
    git checkout "$branch"
  else
    echo "❗ Branch '$branch' does not exist locally—skipping."
    continue
  fi

  # Merge master into branch
  echo "🧬 Merging master into $branch..."
  if git merge master --no-edit; then
    echo "✅ Merge clean."
    git push origin "$branch"
    echo "🚀 [$branch] Pushed updated branch to origin."
  else
    echo "❌ Conflict in [$branch]. Manual intervention needed."
    git merge --abort
    continue
  fi
done

# Switch back to master
git checkout master
echo ""
echo "🎉 Sync complete. All branches updated where possible!"