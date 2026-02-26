#!/bin/bash
# =============================================================================
# Local Codespace test runner
# =============================================================================
# Validates setup.sh behavior without re-cloning repos or re-installing deps.
# Run this inside a Docker container on the same network as the dev infra:
#
#   docker run --rm -it \
#     -v c:/gh/xshopai:/workspaces \
#     --network xshopai-dev-network \
#     mcr.microsoft.com/devcontainers/universal:2 \
#     bash /workspaces/dev/.devcontainer/test-local.sh
#
# The -v mount makes all locally-cloned repos available at /workspaces/*,
# which is exactly where setup.sh expects them inside a Codespace.
# =============================================================================

set -e

WORKSPACES_DIR="/workspaces"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log()     { echo -e "${BLUE}[test]${NC} $1"; }
success() { echo -e "${GREEN}[test]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[test]${NC} ⚠ $1"; }
fail()    { echo -e "${RED}[test]${NC} ✗ $1"; }

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║   xshopai Codespace — Local Setup Test        ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Repos expected at:  $WORKSPACES_DIR/*"
echo "  (skipping clone + dep install — assumed already done)"
echo ""

# =============================================================================
# STEP 1: Verify expected repos exist
# =============================================================================
log "Checking cloned repos..."
REPOS=(
  "admin-service" "admin-ui" "audit-service" "auth-service" "cart-service"
  "chat-service" "customer-ui" "db-seeder" "inventory-service"
  "notification-service" "order-processor-service" "order-service"
  "payment-service" "product-service" "review-service" "user-service" "web-bff"
)
MISSING=0
for repo in "${REPOS[@]}"; do
  if [ -d "$WORKSPACES_DIR/$repo" ]; then
    echo -e "  ${GREEN}✓${NC} $repo"
  else
    fail "$repo — NOT FOUND at $WORKSPACES_DIR/$repo"
    MISSING=$((MISSING + 1))
  fi
done
[ "$MISSING" -gt 0 ] && echo "" && warn "$MISSING repo(s) missing — clone them first"
echo ""

# =============================================================================
# STEP 2: Write .env files for Node / Python services
# =============================================================================
log "Writing service .env files..."
ALL_SERVICES=(
  "admin-service" "audit-service" "auth-service" "cart-service" "chat-service"
  "inventory-service" "notification-service" "product-service" "review-service"
  "user-service" "web-bff"
)
for svc in "${ALL_SERVICES[@]}"; do
  target="$WORKSPACES_DIR/$svc/.env"
  if [ -f "$WORKSPACES_DIR/$svc/.env.http" ]; then
    cp "$WORKSPACES_DIR/$svc/.env.http" "$target"
    echo -e "  ${GREEN}✓${NC} $svc  (.env.http → .env)"
  elif [ -f "$WORKSPACES_DIR/$svc/.env.example" ]; then
    cp "$WORKSPACES_DIR/$svc/.env.example" "$target"
    echo -e "  ${YELLOW}~${NC} $svc  (.env.example → .env)"
  else
    fail "$svc — no .env template found"
  fi
done
echo ""

# =============================================================================
# STEP 3: Write appsettings.Development.json / application-dev.yml
# =============================================================================
log "Writing .NET / Java config files..."

ORDER_SETTINGS="$WORKSPACES_DIR/order-service/OrderService.Api/appsettings.Development.json"
if [ -f "$ORDER_SETTINGS" ]; then
  cat > "$ORDER_SETTINGS" << 'EOF'
{
  "SERVICE_INVOCATION_MODE": "http",
  "MESSAGING_PROVIDER": "rabbitmq",
  "Dapr": { "Enabled": false },
  "RabbitMQ": {
    "Host": "rabbitmq",
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
  "DATABASE_CONNECTION_STRING": "Server=order-sqlserver,1433;Database=order_service_db;User Id=sa;Password=Admin123!;TrustServerCertificate=True;MultipleActiveResultSets=true;Encrypt=False",
  "Tracing": {
    "Exporter": "zipkin",
    "ZipkinEndpoint": "http://zipkin:9411/api/v2/spans",
    "ServiceName": "order-service"
  }
}
EOF
  success "order-service  appsettings.Development.json"
else
  fail "order-service appsettings.Development.json not found"
fi

PAYMENT_SETTINGS="$WORKSPACES_DIR/payment-service/PaymentService/appsettings.Development.json"
if [ -f "$PAYMENT_SETTINGS" ]; then
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
    "Host": "rabbitmq",
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
    "DefaultConnection": "Server=payment-sqlserver,1433;Database=payment_service_db;User Id=sa;Password=Admin123!;TrustServerCertificate=True;MultipleActiveResultSets=true;Encrypt=False"
  },
  "Tracing": {
    "Exporter": "zipkin",
    "ZipkinEndpoint": "http://zipkin:9411/api/v2/spans",
    "ServiceName": "payment-service"
  }
}
EOF
  success "payment-service  appsettings.Development.json"
else
  fail "payment-service appsettings.Development.json not found"
fi

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
  host: rabbitmq
  port: 5672
  username: admin
  password: admin123
  virtual-host: /
  exchange: order-processor-events
  queue: order-processor-queue

spring:
  datasource:
    url: jdbc:postgresql://order-processor-postgres:5432/order_processor_db
    username: postgres
    password: postgres

logging:
  level:
    com.xshopai.orderprocessor: INFO
EOF
success "order-processor-service  application-dev.yml"
echo ""

# =============================================================================
# STEP 4: Verify written config hostnames (no localhost left behind)
# =============================================================================
log "Verifying no 'localhost' references in written configs..."
CONFIGS=(
  "$WORKSPACES_DIR/order-service/OrderService.Api/appsettings.Development.json"
  "$WORKSPACES_DIR/payment-service/PaymentService/appsettings.Development.json"
  "$WORKSPACES_DIR/order-processor-service/src/main/resources/application-dev.yml"
)
BAD=0
for f in "${CONFIGS[@]}"; do
  if grep -q "localhost" "$f" 2>/dev/null; then
    fail "$f still contains 'localhost'"
    BAD=$((BAD + 1))
  else
    echo -e "  ${GREEN}✓${NC} $(basename $f) — no localhost refs"
  fi
done
[ "$BAD" -gt 0 ] && { echo ""; fail "Some configs still reference localhost — fix before committing"; exit 1; }
echo ""

# =============================================================================
# STEP 5: Run db-seeder
# =============================================================================
log "Installing db-seeder Python dependencies..."
pip install -q -r "$WORKSPACES_DIR/db-seeder/seed/requirements.txt"
success "db-seeder deps installed"

log "Writing db-seeder .env..."
cat > "$WORKSPACES_DIR/db-seeder/seed/.env" << 'EOF'
USER_MONGODB_URI=mongodb://admin:admin123@user-mongodb:27017/user_service_db?authSource=admin
PRODUCT_MONGODB_URI=mongodb://admin:admin123@product-mongodb:27017/product_service_db?authSource=admin
REVIEW_MONGODB_URI=mongodb://admin:admin123@review-mongodb:27017/review_service_db?authSource=admin

POSTGRES_HOST=audit-postgres
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=audit_service_db

MYSQL_SERVER_CONNECTION=mysql+pymysql://admin:admin123@inventory-mysql:3306
INVENTORY_DB_NAME=inventory_service_db

ORDER_SQLSERVER_HOST=order-sqlserver
ORDER_SQLSERVER_PORT=1433
ORDER_SQLSERVER_USER=sa
ORDER_SQLSERVER_PASSWORD=Admin123!
ORDER_SQLSERVER_DB=order_service_db

PAYMENT_SQLSERVER_HOST=payment-sqlserver
PAYMENT_SQLSERVER_PORT=1433
PAYMENT_SQLSERVER_USER=sa
PAYMENT_SQLSERVER_PASSWORD=Admin123!
PAYMENT_SQLSERVER_DB=payment_service_db

REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis_dev_pass_123
EOF

log "Running db-seeder (this will take ~30 s for SQL Server init)..."
cd "$WORKSPACES_DIR/db-seeder/seed"
python seed.py

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Local test complete — setup.sh is valid ✓    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
