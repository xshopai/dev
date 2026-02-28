#!/bin/bash
# =============================================================================
# 03-env.sh — Seed .env files and write runtime configs for all services
# =============================================================================
# For LOCAL development — uses localhost with host-mapped ports (no hostname
# patching needed, unlike the Codespace version).
#
# - Node/Python/TypeScript services: .env.http → .env (or .env.example)
# - .NET services: appsettings.Http.json → appsettings.Development.json
# - Java service: application-http.yml → application-dev.yml
#
# Idempotent: copies only when target does not already exist.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(dirname "$SCRIPT_DIR")"
DEV_ROOT="$(dirname "$LOCAL_DIR")"
WORKSPACE_ROOT="$(dirname "$DEV_ROOT")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[env $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[env $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[env $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[env $(_ts)]${NC} ✗ $1"; }

# seed_env <service-name>
# For local dev, .env.http / .env.example already contain localhost values —
# we just copy them without any hostname patching.
seed_env() {
  local svc="$1"
  local target="$WORKSPACE_ROOT/$svc/.env"
  local http="$WORKSPACE_ROOT/$svc/.env.http"
  local example="$WORKSPACE_ROOT/$svc/.env.example"

  if [ -f "$target" ]; then
    success "$svc  (.env exists)"
    return
  fi

  if [ -f "$http" ]; then
    cp "$http" "$target"
    success "$svc  (.env.http → .env)"
  elif [ -f "$example" ]; then
    cp "$example" "$target"
    success "$svc  (.env.example → .env)"
  else
    warn "$svc — no .env template found"
  fi
}

# =============================================================================
# 1. dev infrastructure .env
# =============================================================================
DEV_ENV="$DEV_ROOT/.env"
if [ ! -f "$DEV_ENV" ]; then
  cp "$DEV_ROOT/.env.example" "$DEV_ENV" 2>/dev/null && success "dev/.env" || warn "dev — no .env.example found"
else
  success "dev/.env already exists"
fi

# =============================================================================
# 2. Node / TypeScript / Python services (.env)
# =============================================================================
log "Seeding .env files..."
ENV_SERVICES=(
  "admin-service" "audit-service" "auth-service"
  "cart-service" "chat-service"
  "inventory-service" "notification-service"
  "product-service" "review-service"
  "user-service" "web-bff"
  "admin-ui" "customer-ui"
)
for svc in "${ENV_SERVICES[@]}"; do
  seed_env "$svc"
done

# =============================================================================
# 3. order-service — appsettings.Development.json
# =============================================================================
log "Writing .NET / Java configs..."
ORDER_HTTP="$WORKSPACE_ROOT/order-service/OrderService.Api/appsettings.Http.json"
ORDER_DEV="$WORKSPACE_ROOT/order-service/OrderService.Api/appsettings.Development.json"
if [ -f "$ORDER_HTTP" ] && [ ! -f "$ORDER_DEV" ]; then
  cp "$ORDER_HTTP" "$ORDER_DEV"
  success "order-service  (appsettings.Http.json → Development.json)"
elif [ -f "$ORDER_DEV" ]; then
  success "order-service  (appsettings.Development.json exists)"
else
  warn "order-service  appsettings.Http.json not found"
fi

# =============================================================================
# 4. payment-service — appsettings.Development.json
# =============================================================================
PAYMENT_HTTP="$WORKSPACE_ROOT/payment-service/PaymentService/appsettings.Http.json"
PAYMENT_DEV="$WORKSPACE_ROOT/payment-service/PaymentService/appsettings.Development.json"
if [ -f "$PAYMENT_HTTP" ] && [ ! -f "$PAYMENT_DEV" ]; then
  cp "$PAYMENT_HTTP" "$PAYMENT_DEV"
  success "payment-service  (appsettings.Http.json → Development.json)"
elif [ -f "$PAYMENT_DEV" ]; then
  success "payment-service  (appsettings.Development.json exists)"
else
  warn "payment-service  appsettings.Http.json not found"
fi

# =============================================================================
# 5. order-processor-service — application-dev.yml
# =============================================================================
OPS_HTTP="$WORKSPACE_ROOT/order-processor-service/src/main/resources/application-http.yml"
OPS_DEV="$WORKSPACE_ROOT/order-processor-service/src/main/resources/application-dev.yml"
if [ -f "$OPS_HTTP" ] && [ ! -f "$OPS_DEV" ]; then
  cp "$OPS_HTTP" "$OPS_DEV"
  success "order-processor-service  (application-http.yml → application-dev.yml)"
elif [ -f "$OPS_DEV" ]; then
  success "order-processor-service  (application-dev.yml exists)"
else
  warn "order-processor-service  application-http.yml not found"
fi

success "Environment configuration complete"
