#!/usr/bin/env bash
# Push helper for GitHub Codespaces or cross-repo workflows
# Usage:
#   ./push-repo.sh <GITHUB_PERSONAL_ACCESS_TOKEN>
#   or: GH_PAT=ghp_xxx ./push-repo.sh

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

TOKEN="${1:-${GH_PAT:-}}"
REMOTE_URL=$(git config remote.origin.url | sed -E 's#^https?://([^@]+@)?#https://#')

if [ -n "$TOKEN" ]; then
  echo "Pushing using provided access token..."
  PUSH_URL=$(echo "$REMOTE_URL" | sed "s#https://#https://${TOKEN}@#")
  git push "$PUSH_URL" main
  echo "✅ Push successful!"
else
  echo "Attempting push with default environment credentials..."
  if git push origin main 2>/dev/null; then
    echo "✅ Push successful!"
  else
    echo "⚠️  Codespaces default token only has write permission to the host repo."
    echo ""
    echo "To push this repository, supply a GitHub Personal Access Token (classic with 'repo' scope):"
    echo "  ./push-repo.sh <YOUR_GITHUB_PAT>"
    echo ""
    echo "Generate a token at: https://github.com/settings/tokens"
    exit 1
  fi
fi
