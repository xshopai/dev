#!/bin/bash
# =============================================================================
# 03-env.sh — Seed .env files and write runtime configs for all services
# =============================================================================
# For LOCAL development — uses localhost with host-mapped ports.
#
# Each service is processed individually in a flat list:
# - Node/Python/TypeScript: .env.example → .env
# - .NET services: appsettings.Direct.json → appsettings.Development.json
# - Java services: application-direct.yml → application-dev.yml
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

# =============================================================================
# Per-service config seeding — handles .env, appsettings, and application.yml
# =============================================================================
seed_service_config() {
  local svc="$1"
  local svc_dir="$WORKSPACE_ROOT/$svc"

  if [ ! -d "$svc_dir" ]; then
    warn "$svc — directory not found, skipping"
    return
  fi

  # --- .env file (Node / TypeScript / Python / UI services) ---
  local env_target="$svc_dir/.env"
  local env_example="$svc_dir/.env.example"

  if [ -f "$env_target" ]; then
    success "$svc  (.env exists)"
  elif [ -f "$env_example" ]; then
    cp "$env_example" "$env_target"
    success "$svc  (.env.example → .env)"
  fi

  # --- .NET appsettings (order-service) ---
  if [ "$svc" = "order-service" ]; then
    local order_http="$svc_dir/OrderService.Api/appsettings.Direct.json"
    local order_dev="$svc_dir/OrderService.Api/appsettings.Development.json"
    if [ -f "$order_dev" ]; then
      success "$svc  (appsettings.Development.json exists)"
    elif [ -f "$order_http" ]; then
      cp "$order_http" "$order_dev"
      success "$svc  (appsettings.Direct.json → Development.json)"
    else
      warn "$svc  appsettings.Direct.json not found"
    fi
  fi

  # --- .NET appsettings (payment-service) ---
  if [ "$svc" = "payment-service" ]; then
    local pay_http="$svc_dir/PaymentService/appsettings.Direct.json"
    local pay_dev="$svc_dir/PaymentService/appsettings.Development.json"
    if [ -f "$pay_dev" ]; then
      success "$svc  (appsettings.Development.json exists)"
    elif [ -f "$pay_http" ]; then
      cp "$pay_http" "$pay_dev"
      success "$svc  (appsettings.Direct.json → Development.json)"
    else
      warn "$svc  appsettings.Direct.json not found"
    fi
  fi

  # --- Java application-dev.yml (order-processor-service) ---
  if [ "$svc" = "order-processor-service" ]; then
    local ops_http="$svc_dir/src/main/resources/application-direct.yml"
    local ops_dev="$svc_dir/src/main/resources/application-dev.yml"
    if [ -f "$ops_dev" ]; then
      success "$svc  (application-dev.yml exists)"
    elif [ -f "$ops_http" ]; then
      cp "$ops_http" "$ops_dev"
      success "$svc  (application-direct.yml → application-dev.yml)"
    else
      warn "$svc  application-direct.yml not found"
    fi
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
# 2. All services — processed one at a time
# =============================================================================
ALL_SERVICES=(
  "admin-service"
  "audit-service"
  "auth-service"
  "cart-service"
  "chat-service"
  "inventory-service"
  "notification-service"
  "product-service"
  "review-service"
  "user-service"
  "web-bff"
  "admin-ui"
  "customer-ui"
  "order-service"
  "payment-service"
  "order-processor-service"
)

log "Seeding config for all services..."
for svc in "${ALL_SERVICES[@]}"; do
  seed_service_config "$svc"
done

success "Environment configuration complete"
