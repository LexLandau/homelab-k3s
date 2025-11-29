#!/bin/bash
# Quick git push script
# Usage: ./update-github.sh "commit message"

set -e

# Remove Windows Zone.Identifier files (WSL artifact)
find . -name "*Zone.Identifier" -type f -delete 2>/dev/null || true

git add -A
git status

if [ -n "$1" ]; then
    git commit -m "$1"
else
    git commit -m "update"
fi

git push origin main

echo "Done. ArgoCD syncs in ~3 minutes."
