#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib.sh"

cd "$PROJECT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Update failed: this directory is not a git repository."
    exit 1
fi

old_commit="$(git rev-parse HEAD)"
installed_commit="$(clipai_installed_commit)"
installed_path="$(clipai_installed_path)"

echo "Checking for updates..."
if ! git pull --ff-only; then
    echo ""
    echo "Update failed: git pull did not complete."
    echo "Resolve the git pull failure in this repository, then run update again."
    exit 1
fi

new_commit="$(git rev-parse HEAD)"

if [ "$old_commit" = "$new_commit" ] \
    && [ "$installed_commit" = "$new_commit" ] \
    && [ -n "$installed_path" ] \
    && [ -x "$installed_path" ]; then
    echo "ClipAI is already up to date. Commit $(clipai_short_commit "$new_commit") is already installed."
    exit 0
fi

if [ "$old_commit" = "$new_commit" ]; then
    echo "Repository is already up to date, but the installed copy is missing or stale. Reinstalling..."
else
    echo "Repository updated from $(clipai_short_commit "$old_commit") to $(clipai_short_commit "$new_commit"). Reinstalling..."
fi

"$SCRIPT_DIR/install.sh"

echo ""
echo "Update complete."
