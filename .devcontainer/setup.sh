#!/bin/bash
# =============================================================================
# xshopai Codespace Setup Script
# =============================================================================
# Runs once after the devcontainer is first created (postCreateCommand).
# Clones all service repositories, installs every runtime's dependencies,
# boots the shared infrastructure, and opens the multi-root workspace.
# =============================================================================

set -e

WORKSPACES_DIR="/workspaces"
ORG="xshopai"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[setup]${NC} $1"; }
success() { echo -e "${GREEN}[setup]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[setup]${NC} ⚠ $1"; }

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   xshopai Platform — Codespace Setup     ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# 1. Clone all service repositories in parallel
# =============================================================================
REPOS=(
  "admin-service"
  "admin-ui"
  "audit-service"
  "auth-service"
  "cart-service"
  "chat-service"
  "customer-ui"
  "db-seeder"
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

log "Cloning service repositories..."
for repo in "${REPOS[@]}"; do
  target="$WORKSPACES_DIR/$repo"
  if [ -d "$target/.git" ]; then
    warn "$repo already exists — skipping"
  else
    log "  Cloning $repo..."
    gh repo clone "$ORG/$repo" "$target" -- --depth 1 &
  fi
done
wait
success "All repositories cloned"

# =============================================================================
# 2. Install Node.js dependencies for all JS/TS services in parallel
# =============================================================================
NODE_SERVICES=(
  "admin-service"
  "admin-ui"
  "audit-service"
  "auth-service"
  "cart-service"
  "chat-service"
  "customer-ui"
  "notification-service"
  "review-service"
  "user-service"
  "web-bff"
)

log "Installing Node.js dependencies..."
for svc in "${NODE_SERVICES[@]}"; do
  path="$WORKSPACES_DIR/$svc"
  if [ -f "$path/package.json" ]; then
    (
      cd "$path"
      # npm ci is faster; fall back to npm install if lockfile is absent
      if [ -f "package-lock.json" ]; then
        npm ci --prefer-offline --silent 2>&1 | tail -1
      else
        npm install --silent 2>&1 | tail -1
      fi
      echo -e "  ${GREEN}✓${NC} $svc"
    ) &
  fi
done
wait
success "Node.js dependencies installed"

# =============================================================================
# 3. Install Python dependencies in parallel
# =============================================================================
PYTHON_SERVICES=(
  "inventory-service"
  "product-service"
)

log "Installing Python dependencies..."
for svc in "${PYTHON_SERVICES[@]}"; do
  path="$WORKSPACES_DIR/$svc"
  req="$path/requirements.txt"
  if [ -f "$req" ]; then
    (
      pip install -q -r "$req"
      echo -e "  ${GREEN}✓${NC} $svc"
    ) &
  fi
done
wait
success "Python dependencies installed"

# =============================================================================
# 4. Restore .NET dependencies in parallel
# =============================================================================
DOTNET_SERVICES=(
  "order-service"
  "payment-service"
)

log "Restoring .NET dependencies..."
for svc in "${DOTNET_SERVICES[@]}"; do
  path="$WORKSPACES_DIR/$svc"
  sln=$(find "$path" -maxdepth 2 -name "*.sln" 2>/dev/null | head -1)
  if [ -n "$sln" ]; then
    (
      dotnet restore "$sln" --verbosity quiet
      echo -e "  ${GREEN}✓${NC} $svc"
    ) &
  fi
done
wait
success ".NET dependencies restored"

# =============================================================================
# 5. Resolve Java / Maven dependencies
# =============================================================================
log "Resolving Java dependencies (order-processor-service)..."
OPS_PATH="$WORKSPACES_DIR/order-processor-service"
if [ -f "$OPS_PATH/pom.xml" ]; then
  (
    cd "$OPS_PATH"
    mvn -q dependency:resolve -DincludeScope=compile
    echo -e "  ${GREEN}✓${NC} order-processor-service"
  )
fi
success "Java dependencies resolved"

# =============================================================================
# 6. Copy .env files for every service (only on first run, never overwrite)
# =============================================================================

# dev infrastructure .env
ENV_FILE="$WORKSPACES_DIR/dev/.env"
if [ ! -f "$ENV_FILE" ]; then
  cp "$WORKSPACES_DIR/dev/.env.example" "$ENV_FILE"
  success "Created dev/.env from .env.example"
else
  warn "dev/.env already exists — not overwriting"
fi

# For each service, prefer .env.http (direct HTTP mode), fall back to .env.example
# NOTE: order-service, payment-service, order-processor-service use JSON/YAML config — handled below
log "Seeding service .env files..."
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
)
for svc in "${ALL_SERVICES[@]}"; do
  target="$WORKSPACES_DIR/$svc/.env"
  if [ -f "$target" ]; then
    warn "$svc/.env already exists — not overwriting"
  elif [ -f "$WORKSPACES_DIR/$svc/.env.http" ]; then
    cp "$WORKSPACES_DIR/$svc/.env.http" "$target"
    echo -e "  ${GREEN}✓${NC} $svc  (.env.http)"
  elif [ -f "$WORKSPACES_DIR/$svc/.env.example" ]; then
    cp "$WORKSPACES_DIR/$svc/.env.example" "$target"
    echo -e "  ${GREEN}✓${NC} $svc  (.env.example)"
  else
    warn "$svc — no .env template found, skipping"
  fi
done
success "Service .env files seeded"

# =============================================================================
# 6b. Write Codespace config for .NET and Java services
#     These services use JSON/YAML config files (not .env).
#     scripts/dev.sh in each repo copies the Development/dev variant before
#     starting, so we write Codespace-correct versions here.
# =============================================================================
log "Writing Codespace config for .NET / Java services..."

# --- order-service: appsettings.Development.json ---
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
  echo -e "  ${GREEN}✓${NC} order-service  (appsettings.Development.json)"
else
  warn "order-service appsettings.Development.json not found — skipping"
fi

# --- payment-service: appsettings.Development.json ---
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
  echo -e "  ${GREEN}✓${NC} payment-service  (appsettings.Development.json)"
else
  warn "payment-service appsettings.Development.json not found — skipping"
fi

# --- order-processor-service: application-dev.yml ---
# scripts/dev.sh copies application-dev.yml → application.yml (file doesn't
# ship in the repo; we create it here for the Codespace)
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
echo -e "  ${GREEN}✓${NC} order-processor-service  (application-dev.yml)"
success "Non-.env service configs written"

# =============================================================================
# 7. Start shared infrastructure (databases, RabbitMQ, Redis, etc.)
# =============================================================================
log "Starting infrastructure services..."
cd "$WORKSPACES_DIR/dev"
docker compose up -d
success "Infrastructure is running"

# =============================================================================
# 8. Seed databases with sample data via db-seeder
# =============================================================================
log "Installing db-seeder Python dependencies..."
pip install -q -r "$WORKSPACES_DIR/db-seeder/seed/requirements.txt"
success "db-seeder dependencies installed"

# Write seed/.env pointing to Docker Compose service hostnames (internal network)
log "Writing db-seeder .env..."
cat > "$WORKSPACES_DIR/db-seeder/seed/.env" << 'EOF'
# MongoDB (internal Docker service hostnames + port 27017)
USER_MONGODB_URI=mongodb://admin:admin123@user-mongodb:27017/user_service_db?authSource=admin
PRODUCT_MONGODB_URI=mongodb://admin:admin123@product-mongodb:27017/product_service_db?authSource=admin
REVIEW_MONGODB_URI=mongodb://admin:admin123@review-mongodb:27017/review_service_db?authSource=admin

# PostgreSQL — audit-service
POSTGRES_HOST=audit-postgres
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=audit_service_db

# MySQL — inventory-service
MYSQL_SERVER_CONNECTION=mysql+pymysql://admin:admin123@inventory-mysql:3306
INVENTORY_DB_NAME=inventory_service_db

# SQL Server — order-service
ORDER_SQLSERVER_HOST=order-sqlserver
ORDER_SQLSERVER_PORT=1433
ORDER_SQLSERVER_USER=sa
ORDER_SQLSERVER_PASSWORD=Admin123!
ORDER_SQLSERVER_DB=order_service_db

# SQL Server — payment-service
PAYMENT_SQLSERVER_HOST=payment-sqlserver
PAYMENT_SQLSERVER_PORT=1433
PAYMENT_SQLSERVER_USER=sa
PAYMENT_SQLSERVER_PASSWORD=Admin123!
PAYMENT_SQLSERVER_DB=payment_service_db

# Redis — cart-service
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis_dev_pass_123
EOF
success "db-seeder .env written"

# Wait for databases to accept connections (SQL Server needs the longest warm-up)
log "Waiting 30 s for all databases to be ready..."
sleep 30

log "Running db-seeder..."
cd "$WORKSPACES_DIR/db-seeder/seed"
python seed.py && success "Database seeding complete" || warn "db-seeder exited with errors — check output above"

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  xshopai platform is ready!                            ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Infrastructure:  running via Docker Compose            ║${NC}"
echo -e "${GREEN}║  Code:            all repos cloned to /workspaces/      ║${NC}"
echo -e "${GREEN}║  Databases:       seeded with sample data               ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Start all services:  cd /workspaces/dev && ./dev.sh    ║${NC}"
echo -e "${GREEN}║  Stop all services:   ./dev.sh --stop                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Open the multi-root workspace for full code navigation:"
echo -e "  ${CYAN}code /workspaces/dev/xshopai.code-workspace${NC}"
echo ""
