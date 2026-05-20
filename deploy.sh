#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$REPO_ROOT/apps/central_hub"
BUILD_DIR="$APP_DIR/build/web"
REMOTE="https://github.com/z1parus/SiE.git"
BRANCH="gh-pages"

echo "==> Building Flutter web..."
cd "$APP_DIR"
MSYS_NO_PATHCONV=1 flutter build web --release --base-href "/SiE/"

echo "==> Copying index.html → 404.html..."
cp "$BUILD_DIR/index.html" "$BUILD_DIR/404.html"

echo "==> Deploying to $BRANCH..."
cd "$BUILD_DIR"

if [ ! -d ".git" ]; then
  git init
  git remote add origin "$REMOTE"
else
  # Ensure remote is set correctly even if .git already exists
  git remote set-url origin "$REMOTE" 2>/dev/null || git remote add origin "$REMOTE"
fi

# Inherit identity from global config; fall back to repo values
GIT_USER=$(git -C "$REPO_ROOT" config user.name  2>/dev/null || echo "z1pa")
GIT_EMAIL=$(git -C "$REPO_ROOT" config user.email 2>/dev/null || echo "zipadump@gmail.com")
git config user.name  "$GIT_USER"
git config user.email "$GIT_EMAIL"

git checkout --orphan "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
git add -A
git commit -m "deploy: $(date -u '+%Y-%m-%d %H:%M UTC')"
git push --force origin "$BRANCH"

echo "==> Done. Live at: https://z1parus.github.io/SiE/"
