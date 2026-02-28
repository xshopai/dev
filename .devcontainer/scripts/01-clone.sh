#!/bin/bash
# =============================================================================
# 01-clone.sh — Clone all xshopai service repositories in parallel
# =============================================================================
# Called by setup.sh. Safe to re-run: existing repos are skipped.
# =============================================================================

WORKSPACES_DIR="/workspaces"
ORG="xshopai"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[clone $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[clone $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[clone $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[clone $(_ts)]${NC} ✗ $1"; }

REPOS=(
  "admin-service"
  "admin-ui"
  "audit-service"
  "auth-service"
  "cart-service"
  "chat-service"
  "customer-ui"
  "db-seeder"
  "docs"
  "deployment"
  "infrastructure"
  "inventory-service"
  "notification-service"
  "order-processor-service"
  "order-service"
  "payment-service"
  "product-service"
  "review-service"
  "user-service"
  "web-bff"
)

PIDS=()
declare -A PID_REPO  # Map PID → repo name for error reporting
SKIPPED=0
CLONING=0

for repo in "${REPOS[@]}"; do
  target="$WORKSPACES_DIR/$repo"
  if [ -d "$target/.git" ]; then
    warn "$repo already exists — skipping"
    (( SKIPPED++ )) || true
  else
    log "Cloning $repo..."
    git clone --depth 1 "https://github.com/$ORG/$repo.git" "$target" &
    PID_REPO[$!]="$repo"
    PIDS+=($!)
    (( CLONING++ )) || true
  fi
done

# Wait for all clones and collect exit codes
FAILED=()
for pid in "${PIDS[@]}"; do
  if ! wait "$pid"; then
    FAILED+=("${PID_REPO[$pid]}")
  fi
done

# Fix execute permissions on all newly cloned scripts
find "$WORKSPACES_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

if [ ${#FAILED[@]} -gt 0 ]; then
  err "Failed to clone: ${FAILED[*]}"
  exit 1
fi

success "Cloned $CLONING repo(s), skipped $SKIPPED existing"
