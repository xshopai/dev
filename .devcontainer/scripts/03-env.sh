#!/bin/bash
# =============================================================================
# 03-env.sh — Seed .env files and write runtime configs for all services
# =============================================================================
# - Node/Python/TypeScript services: .env.http → .env (or .env.example)
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
# Patch localhost DB/broker hostnames → Docker container_name values.
# Infra containers use 'container_name: dev-<svc>' in docker-compose.yml.
# container_name DNS works from ANY container on the same network;
# Compose service-name aliases only work within the same Compose project.
# Inter-service HTTP URLs (localhost:800x) are intentionally left as-is.
#
# IMPORTANT: sed patterns are idempotent — safe to run on an already-patched
# file (dev-user-mongodb:27017 does not match localhost:27018, so it's a no-op).
# -----------------------------------------------------------------------------
patch_hostnames() {
  local f="$1"
  [ -f "$f" ] || return
  sed -i \
    -e 's|localhost:27018|dev-user-mongodb:27017|g' \
    -e 's|localhost:27019|dev-product-mongodb:27017|g' \
    -e 's|localhost:27020|dev-review-mongodb:27017|g' \
    -e 's|POSTGRES_HOST=localhost|POSTGRES_HOST=dev-audit-postgres|g' \
    -e 's|POSTGRES_PORT=5434|POSTGRES_PORT=5432|g' \
    -e 's|RABBITMQ_URL=amqp://admin:admin123@localhost|RABBITMQ_URL=amqp://admin:admin123@dev-rabbitmq|g' \
    -e 's|localhost:3306|dev-inventory-mysql:3306|g' \
    -e 's|REDIS_HOST=localhost|REDIS_HOST=dev-redis|g' \
    -e 's|SMTP_HOST=localhost|SMTP_HOST=dev-mailpit|g' \
    -e 's|SMTP_PORT=1025.*|SMTP_PORT=1025|g' \
    "$f"
}

seed_env() {
  local svc="$1"
  local target="$WORKSPACES_DIR/$svc/.env"

  if [ -f "$target" ]; then
    # File already exists (committed in repo with localhost hostnames).
    # Always patch so infra connections resolve correctly inside the container.
    patch_hostnames "$target"
    success "$svc  (.env exists — hostnames patched)"
    return
  fi

  if [ -f "$WORKSPACES_DIR/$svc/.env.http" ]; then
    cp "$WORKSPACES_DIR/$svc/.env.http" "$target"
    patch_hostnames "$target"
    success "$svc  (.env.http → .env)"
  elif [ -f "$WORKSPACES_DIR/$svc/.env.example" ]; then
    cp "$WORKSPACES_DIR/$svc/.env.example" "$target"
    patch_hostnames "$target"
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
)
for svc in "${ENV_SERVICES[@]}"; do
  seed_env "$svc"
done

# =============================================================================
# 3. order-service — appsettings.Development.json
# =============================================================================
log "Writing .NET / Java configs..."
ORDER_SETTINGS="$WORKSPACES_DIR/order-service/OrderService.Api/appsettings.Development.json"
if [ ! -f "$ORDER_SETTINGS" ]; then
  warn "order-service appsettings.Development.json not found"
else
  cat > "$ORDER_SETTINGS" << 'EOF'
{
  "SERVICE_INVOCATION_MODE": "http",
  "MESSAGING_PROVIDER": "rabbitmq",
  "Dapr": { "Enabled": false },
  "RabbitMQ": {
    "Host": "dev-rabbitmq",
    "Port": 5672,
    "Username": "admin",
    "Password": "admin123",
    "VirtualHost": "/",
    "ExchangeName": "xshopai.events"
  },
  "Jwt": {
    "Secret": "8tDBDMcpxroHoHjXjk8xp/uAn8rzD4y8ZZremFkC4gI=",
    "Issuer": "auth-service",
    "Audience": "xshopai-platform"
  },
  "DATABASE_CONNECTION_STRING": "Server=dev-order-sqlserver,1433;Database=order_service_db;User Id=sa;Password=Admin123!;TrustServerCertificate=True;MultipleActiveResultSets=true;Encrypt=False",
  "Tracing": {
    "Exporter": "zipkin",
    "ZipkinEndpoint": "http://dev-zipkin:9411/api/v2/spans",
    "ServiceName": "order-service"
  }
}
EOF
  success "order-service  (appsettings.Development.json)"
fi

# =============================================================================
# 4. payment-service — appsettings.Development.json
# =============================================================================
PAYMENT_SETTINGS="$WORKSPACES_DIR/payment-service/PaymentService/appsettings.Development.json"
if [ ! -f "$PAYMENT_SETTINGS" ]; then
  warn "payment-service appsettings.Development.json not found"
else
  cat > "$PAYMENT_SETTINGS" << 'EOF'
{
  "SERVICE_INVOCATION_MODE": "http",
  "MESSAGING_PROVIDER": "rabbitmq",
  "Dapr": { "Enabled": false },
  "PaymentProviders": {
    "DefaultProvider": "simulation",
    "Simulation": { "IsEnabled": true, "AutoSuccess": true, "ProcessingDelayMs": 500 },
    "Stripe": { "IsEnabled": false }
  },
  "RabbitMQ": {
    "Host": "dev-rabbitmq",
    "Port": 5672,
    "Username": "admin",
    "Password": "admin123",
    "VirtualHost": "/",
    "ExchangeName": "xshopai.events"
  },
  "Jwt": {
    "Key": "8tDBDMcpxroHoHjXjk8xp/uAn8rzD4y8ZZremFkC4gI=",
    "Issuer": "auth-service",
    "Audience": "xshopai-platform"
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=dev-payment-sqlserver,1433;Database=payment_service_db;User Id=sa;Password=Admin123!;TrustServerCertificate=True;MultipleActiveResultSets=true;Encrypt=False"
  },
  "Tracing": {
    "Exporter": "zipkin",
    "ZipkinEndpoint": "http://dev-zipkin:9411/api/v2/spans",
    "ServiceName": "payment-service"
  }
}
EOF
  success "payment-service  (appsettings.Development.json)"
fi

# =============================================================================
# 5. order-processor-service — application-dev.yml
# =============================================================================
OPS_YML="$WORKSPACES_DIR/order-processor-service/src/main/resources/application-dev.yml"
mkdir -p "$(dirname "$OPS_YML")"
cat > "$OPS_YML" << 'EOF'
server:
  port: ${PORT:8007}

service:
  invocation:
    mode: http

messaging:
  provider: rabbitmq

rabbitmq:
  host: dev-rabbitmq
  port: 5672
  username: admin
  password: admin123
  virtual-host: /
  exchange: order-processor-events
  queue: order-processor-queue

spring:
  datasource:
    url: jdbc:postgresql://dev-order-processor-postgres:5432/order_processor_db
    username: postgres
    password: postgres

logging:
  level:
    com.xshopai.orderprocessor: INFO
EOF
success "order-processor-service  (application-dev.yml)"
