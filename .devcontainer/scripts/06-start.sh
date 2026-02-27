#!/bin/bash
# =============================================================================
# 06-start.sh — Start all xshopai services in dev mode
# =============================================================================
# Delegates to dev.sh which starts every service with the correct runtime
# (node, ts-node, uvicorn, dotnet run, mvn spring-boot:run, etc.)
# =============================================================================

WORKSPACES_DIR="/workspaces"
DEV_DIR="$WORKSPACES_DIR/dev"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[start $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[start $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[start $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[start $(_ts)]${NC} ✗ $1"; }

if [ ! -f "$DEV_DIR/dev.sh" ]; then
  err "dev.sh not found at $DEV_DIR/dev.sh"
  exit 1
fi

log "Starting all services via dev.sh..."
cd "$DEV_DIR"

if bash ./dev.sh; then
  success "All services started"
else
  err "dev.sh exited with errors — some services may not have started"
  exit 1
fi
