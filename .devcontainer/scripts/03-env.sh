#!/bin/bash
# =============================================================================
# 03-env.sh — Seed .env files and write runtime configs for all services
# =============================================================================
# - Node/Python/TypeScript services: .env.example → .env
# - .NET services: writes appsettings.Development.json
# - Java service: writes application-dev.yml
# Idempotent: copies only if .env is missing, but ALWAYS patches hostnames.
# =============================================================================

WORKSPACES_DIR="/workspaces"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[env $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[env $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[env $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[env $(_ts)]${NC} ✗ $1"; }

# -----------------------------------------------------------------------------
# Patch localhost DB/broker hostnames → Docker Compose service names.
# Both the Compose service name (e.g. user-mongodb) and the container_name
# (e.g. dev-user-mongodb) resolve on the xshopai-dev network.  We use bare
# Compose service names here to stay consistent with remoteEnv in
# devcontainer.json.  Inter-service HTTP URLs (localhost:800x) are left as-is.
#
# IMPORTANT: sed patterns are idempotent — safe to run on an already-patched
# file (user-mongodb:27017 does not match localhost:27018, so it's a no-op).
# Also handles previously-patched dev-* hostnames → bare names.
# -----------------------------------------------------------------------------
patch_hostnames() {
  local f="$1"
  [ -f "$f" ] || return
  sed -i \
    -e 's|localhost:27018|user-mongodb:27017|g' \
    -e 's|localhost:27019|product-mongodb:27017|g' \
    -e 's|localhost:27020|review-mongodb:27017|g' \
    -e 's|dev-user-mongodb|user-mongodb|g' \
    -e 's|dev-product-mongodb|product-mongodb|g' \
    -e 's|dev-review-mongodb|review-mongodb|g' \
    -e 's|POSTGRES_HOST=localhost|POSTGRES_HOST=audit-postgres|g' \
    -e 's|POSTGRES_HOST=dev-audit-postgres|POSTGRES_HOST=audit-postgres|g' \
    -e 's|POSTGRES_PORT=5434|POSTGRES_PORT=5432|g' \
    -e 's|RABBITMQ_URL=amqp://admin:admin123@localhost|RABBITMQ_URL=amqp://admin:admin123@rabbitmq|g' \
    -e 's|RABBITMQ_URL=amqp://admin:admin123@dev-rabbitmq|RABBITMQ_URL=amqp://admin:admin123@rabbitmq|g' \
    -e 's|localhost:3306|inventory-mysql:3306|g' \
    -e 's|dev-inventory-mysql|inventory-mysql|g' \
    -e 's|REDIS_HOST=localhost|REDIS_HOST=redis|g' \
    -e 's|REDIS_HOST=dev-redis|REDIS_HOST=redis|g' \
    -e 's|SMTP_HOST=localhost|SMTP_HOST=mailpit|g' \
    -e 's|SMTP_HOST=dev-mailpit|SMTP_HOST=mailpit|g' \
    -e 's|SMTP_PORT=1025.*|SMTP_PORT=1025|g' \
    -e 's|CONSUL_URL=http://localhost:8500|CONSUL_URL=http://consul:8500|g' \
    -e 's|CONSUL_URL=http://dev-consul:8500|CONSUL_URL=http://consul:8500|g' \
    "$f"
}

# Patch localhost hostnames in .NET appsettings JSON files.
# Handles both fresh (localhost) and previously-patched (dev-*) patterns.
patch_appsettings() {
  local f="$1"
  [ -f "$f" ] || return
  sed -i \
    -e 's|"Host": "localhost"|"Host": "rabbitmq"|g' \
    -e 's|"Host": "dev-rabbitmq"|"Host": "rabbitmq"|g' \
    -e 's|Server=localhost,1434;Database=order_service_db|Server=order-sqlserver,1433;Database=order_service_db|g' \
    -e 's|Server=dev-order-sqlserver,1433;Database=order_service_db|Server=order-sqlserver,1433;Database=order_service_db|g' \
    -e 's|Server=localhost,1434;Database=payment_service_db|Server=payment-sqlserver,1433;Database=payment_service_db|g' \
    -e 's|Server=dev-payment-sqlserver,1433;Database=payment_service_db|Server=payment-sqlserver,1433;Database=payment_service_db|g' \
    -e 's|http://localhost:9411|http://zipkin:9411|g' \
    -e 's|http://dev-zipkin:9411|http://zipkin:9411|g' \
    "$f"
}

# Patch localhost hostnames in Java Spring Boot YAML config files.
# Handles both fresh (localhost) and previously-patched (dev-*) patterns.
patch_java_yml() {
  local f="$1"
  [ -f "$f" ] || return
  sed -i \
    -e 's|  host: localhost|  host: rabbitmq|g' \
    -e 's|  host: dev-rabbitmq|  host: rabbitmq|g' \
    -e 's|jdbc:postgresql://localhost:5435/order_processor_db|jdbc:postgresql://order-processor-postgres:5432/order_processor_db|g' \
    -e 's|jdbc:postgresql://dev-order-processor-postgres:5432/order_processor_db|jdbc:postgresql://order-processor-postgres:5432/order_processor_db|g' \
    "$f"
}

seed_env() {
  local svc="$1"
  local target="$WORKSPACES_DIR/$svc/.env"
  local example="$WORKSPACES_DIR/$svc/.env.example"

  # ALWAYS patch .env.example first — service startup scripts (scripts/dev.sh)
  # unconditionally copy .env.example → .env on every launch, which would
  # overwrite any patches we apply to .env.  Patching the source file
  # ensures the copy already contains the correct container hostnames.
  [ -f "$example" ] && patch_hostnames "$example"

  if [ -f "$target" ]; then
    # File already exists (committed in repo with localhost hostnames).
    # Patch it too so it's correct even before the service restarts.
    patch_hostnames "$target"
    success "$svc  (.env exists — hostnames patched)"
    return
  fi

  if [ -f "$example" ]; then
    cp "$example" "$target"
    success "$svc  (.env.example → .env)"
  else
    warn "$svc — no .env template found"
  fi
}

# =============================================================================
# 1. dev infrastructure .env
# =============================================================================
DEV_ENV="$WORKSPACES_DIR/dev/.env"
if [ ! -f "$DEV_ENV" ]; then
  cp "$WORKSPACES_DIR/dev/.env.example" "$DEV_ENV" 2>/dev/null && success "dev/.env" || warn "dev — no .env.example found"
else
  warn "dev/.env already exists — skipping"
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
ORDER_HTTP="$WORKSPACES_DIR/order-service/OrderService.Api/appsettings.Direct.json"
ORDER_DEV="$WORKSPACES_DIR/order-service/OrderService.Api/appsettings.Development.json"
if [ -f "$ORDER_HTTP" ]; then
  patch_appsettings "$ORDER_HTTP"
  cp "$ORDER_HTTP" "$ORDER_DEV"
  success "order-service  (appsettings.Direct.json patched → Development.json)"
else
  warn "order-service  appsettings.Direct.json not found"
fi

# =============================================================================
# 4. payment-service — appsettings.Development.json
# =============================================================================
PAYMENT_HTTP="$WORKSPACES_DIR/payment-service/PaymentService/appsettings.Direct.json"
PAYMENT_DEV="$WORKSPACES_DIR/payment-service/PaymentService/appsettings.Development.json"
if [ -f "$PAYMENT_HTTP" ]; then
  patch_appsettings "$PAYMENT_HTTP"
  cp "$PAYMENT_HTTP" "$PAYMENT_DEV"
  success "payment-service  (appsettings.Direct.json patched → Development.json)"
else
  warn "payment-service  appsettings.Direct.json not found"
fi

# =============================================================================
# 5. order-processor-service — application-dev.yml
# =============================================================================
OPS_HTTP="$WORKSPACES_DIR/order-processor-service/src/main/resources/application-direct.yml"
OPS_DEV="$WORKSPACES_DIR/order-processor-service/src/main/resources/application-dev.yml"
if [ -f "$OPS_HTTP" ]; then
  patch_java_yml "$OPS_HTTP"
  cp "$OPS_HTTP" "$OPS_DEV"
  success "order-processor-service  (application-direct.yml patched → application-dev.yml)"
else
  warn "order-processor-service  application-direct.yml not found"
fi

# =============================================================================
# 6. Codespace-specific patches for React UIs and CORS
# =============================================================================
# In Codespaces, the browser runs on the user's machine — not inside the
# devcontainer.  React apps (customer-ui, admin-ui) fetch from the BFF via
# REACT_APP_BFF_URL, which must be the Codespace forwarded URL, not localhost.
# Similarly, the BFF's CORS allowlist must include the Codespace UI origins.
if [ -n "$CODESPACE_NAME" ]; then
  DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
  BFF_URL="https://${CODESPACE_NAME}-8014.${DOMAIN}"
  CUSTOMER_URL="https://${CODESPACE_NAME}-3000.${DOMAIN}"
  ADMIN_URL="https://${CODESPACE_NAME}-3001.${DOMAIN}"

  log "Codespace detected — patching UI and BFF configs"
  log "  BFF URL:      $BFF_URL"
  log "  Customer UI:  $CUSTOMER_URL"
  log "  Admin UI:     $ADMIN_URL"

  # --- React UI .env.example files (source of truth — scripts/dev.sh copies
  #     .env.example → .env on every start, so we must patch the source) ---
  for ui in admin-ui customer-ui; do
    for envfile in "$WORKSPACES_DIR/$ui/.env.example" "$WORKSPACES_DIR/$ui/.env"; do
      if [ -f "$envfile" ]; then
        sed -i "s|REACT_APP_BFF_URL=.*|REACT_APP_BFF_URL=${BFF_URL}|g" "$envfile"
        # webpack-dev-server WebSocket must use port 443 (Codespace HTTPS proxy)
        grep -q "WDS_SOCKET_PORT" "$envfile" || echo "WDS_SOCKET_PORT=443" >> "$envfile"
        # Bind to all interfaces so Codespace port forwarding can reach the dev server.
        # Without this, CRA binds to 127.0.0.1 only and the forwarded port gets no response.
        grep -q "^HOST=" "$envfile" || echo "HOST=0.0.0.0" >> "$envfile"
        # Skip webpack-dev-server host check — the Codespace forwarded hostname
        # (e.g. name-3000.app.github.dev) is not localhost, so without this the
        # server returns "Invalid Host header" for every request.
        grep -q "^DANGEROUSLY_DISABLE_HOST_CHECK=" "$envfile" || echo "DANGEROUSLY_DISABLE_HOST_CHECK=true" >> "$envfile"
        # Don't try to open a browser from the Codespace terminal
        grep -q "^BROWSER=" "$envfile" || echo "BROWSER=none" >> "$envfile"
      fi
    done
  done
  success "React UI .env patched for Codespace"

  # --- web-bff ALLOWED_ORIGINS — add Codespace UI URLs ---
  for envfile in "$WORKSPACES_DIR/web-bff/.env.example" "$WORKSPACES_DIR/web-bff/.env"; do
    if [ -f "$envfile" ]; then
      # Append Codespace origins to existing ALLOWED_ORIGINS value
      sed -i "s|^ALLOWED_ORIGINS=\(.*\)|ALLOWED_ORIGINS=\1,${CUSTOMER_URL},${ADMIN_URL}|g" "$envfile"
    fi
  done
  success "web-bff CORS origins patched for Codespace"
else
  log "Not running in Codespace — skipping UI URL patches"
fi
