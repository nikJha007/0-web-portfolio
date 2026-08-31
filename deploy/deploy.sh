#!/usr/bin/env bash
# ===========================================================================
# Publish the current commit to the nginx web root. Run this ON the server.
#
#   bash deploy/deploy.sh              # git pull, then sync
#   bash deploy/deploy.sh --skip-pull  # sync whatever is in the working tree
#
# Safe to run repeatedly. Copies only the files nginx needs to serve, so the
# .git directory, deploy scripts, and README never reach the web root.
# ===========================================================================

set -euo pipefail

SKIP_PULL=0
[[ "${1:-}" == "--skip-pull" ]] && SKIP_PULL=1

SRC_DIR="${SRC_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WEB_ROOT="${WEB_ROOT:-/var/www/portfolio}"
NGINX_USER="${NGINX_USER:-nginx}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; exit 1; }

[[ -f "$SRC_DIR/index.html" ]] || die "index.html not found in $SRC_DIR"

# --- pull ------------------------------------------------------------------

if [[ "$SKIP_PULL" -eq 0 ]]; then
  if [[ -d "$SRC_DIR/.git" ]]; then
    log "Pulling latest from origin"
    # --ff-only refuses to create a merge commit, so a dirty or diverged
    # checkout fails loudly instead of silently deploying a merge.
    git -C "$SRC_DIR" pull --ff-only
  else
    log "Not a git checkout, skipping pull"
  fi
fi

# --- sync ------------------------------------------------------------------
# Everything listed here gets published. Add to this list if you add
# top-level files or directories that need to be served.
PUBLISH=(
  index.html
  404.html
  robots.txt
  sitemap.xml
  assets
  posts
)

log "Publishing to $WEB_ROOT"
sudo mkdir -p "$WEB_ROOT"

if command -v rsync >/dev/null 2>&1; then
  EXISTING=()
  for item in "${PUBLISH[@]}"; do
    [[ -e "$SRC_DIR/$item" ]] && EXISTING+=("$SRC_DIR/$item")
  done
  [[ ${#EXISTING[@]} -gt 0 ]] || die "Nothing to publish"

  # --delete removes files in the web root that no longer exist in the repo,
  # which keeps deleted pages from lingering as stale live URLs.
  sudo rsync -a --delete "${EXISTING[@]}" "$WEB_ROOT/"
else
  log "rsync not available, falling back to cp"
  for item in "${PUBLISH[@]}"; do
    [[ -e "$SRC_DIR/$item" ]] && sudo cp -R "$SRC_DIR/$item" "$WEB_ROOT/"
  done
fi

# --- permissions -----------------------------------------------------------

log "Setting ownership to ${NGINX_USER}"
sudo chown -R "${NGINX_USER}:${NGINX_USER}" "$WEB_ROOT"
sudo find "$WEB_ROOT" -type d -exec chmod 755 {} +
sudo find "$WEB_ROOT" -type f -exec chmod 644 {} +

# --- reload ----------------------------------------------------------------
# Validate before reloading so a bad config can never take the site down.

log "Validating nginx config"
sudo nginx -t

log "Reloading nginx"
sudo systemctl reload nginx

log "Done. Published $(cd "$SRC_DIR" && git rev-parse --short HEAD 2>/dev/null || echo 'working tree')"
