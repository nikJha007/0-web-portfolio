#!/usr/bin/env bash
# ===========================================================================
# One-time server setup. Run this ON the EC2 instance, once.
#
#   curl -fsSL <raw-url-of-this-file> -o setup-server.sh
#   bash setup-server.sh https://github.com/you/your-repo.git
#
# Or, if you have already cloned the repo:
#   bash deploy/setup-server.sh
#
# Installs nginx and git, creates the web root, clones the repo if a URL is
# given, installs the nginx config, and does the first deploy.
# ===========================================================================

set -euo pipefail

REPO_URL="${1:-}"
CLONE_DIR="${CLONE_DIR:-$HOME/portfolio-src}"
WEB_ROOT="${WEB_ROOT:-/var/www/portfolio}"
NGINX_USER="nginx"          # 'nginx' on Amazon Linux / RHEL, 'www-data' on Debian

log()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; exit 1; }

# --- packages --------------------------------------------------------------

log "Installing nginx and git"
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y nginx git
elif command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y nginx git
  NGINX_USER="www-data"
else
  die "No dnf or apt-get found. Install nginx and git manually, then re-run."
fi

# --- source checkout -------------------------------------------------------

if [[ -n "$REPO_URL" ]]; then
  if [[ -d "$CLONE_DIR/.git" ]]; then
    log "Repo already present at $CLONE_DIR, fetching instead of cloning"
    git -C "$CLONE_DIR" pull --ff-only
  else
    log "Cloning $REPO_URL into $CLONE_DIR"
    git clone "$REPO_URL" "$CLONE_DIR"
  fi
  SRC_DIR="$CLONE_DIR"
else
  # Assume we are being run from inside the checkout.
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  log "No repo URL given, deploying from $SRC_DIR"
fi

[[ -f "$SRC_DIR/index.html" ]] || die "index.html not found in $SRC_DIR"

# --- web root --------------------------------------------------------------

log "Creating web root at $WEB_ROOT"
sudo mkdir -p "$WEB_ROOT"

# --- nginx config ----------------------------------------------------------

CONF_SRC="$SRC_DIR/deploy/nginx/portfolio.conf"
[[ -f "$CONF_SRC" ]] || die "Missing $CONF_SRC"

if [[ -d /etc/nginx/conf.d ]]; then
  CONF_DEST="/etc/nginx/conf.d/portfolio.conf"
else
  die "Unexpected nginx layout: /etc/nginx/conf.d does not exist"
fi

if [[ -f "$CONF_DEST" ]]; then
  log "Backing up existing config to ${CONF_DEST}.bak"
  sudo cp "$CONF_DEST" "${CONF_DEST}.bak"
fi

log "Installing nginx config to $CONF_DEST"
sudo cp "$CONF_SRC" "$CONF_DEST"

# Debian ships a default site that would otherwise shadow ours.
if [[ -L /etc/nginx/sites-enabled/default ]]; then
  log "Disabling Debian default site"
  sudo rm -f /etc/nginx/sites-enabled/default
fi

# --- start nginx -----------------------------------------------------------
# Must happen before the first deploy, because deploy.sh reloads the service
# and a reload against a never-started unit fails.

log "Enabling nginx at boot and starting it"
sudo systemctl enable --now nginx

# --- first deploy ----------------------------------------------------------

log "Running first deploy"
SRC_DIR="$SRC_DIR" WEB_ROOT="$WEB_ROOT" NGINX_USER="$NGINX_USER" \
  bash "$SRC_DIR/deploy/deploy.sh" --skip-pull

cat <<EOF

Setup complete.

  Source checkout : $SRC_DIR
  Web root        : $WEB_ROOT
  nginx config    : $CONF_DEST

Next steps:
  1. Point your domain's A record at this instance's Elastic IP.
  2. Edit server_name in $CONF_DEST to your real domain.
  3. sudo nginx -t && sudo systemctl reload nginx
  4. Add TLS:
       sudo dnf install -y certbot python3-certbot-nginx
       sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
       sudo certbot renew --dry-run

To publish future changes:  bash $SRC_DIR/deploy/deploy.sh
EOF
