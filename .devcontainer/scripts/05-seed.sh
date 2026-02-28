#!/bin/bash
# =============================================================================
# 05-seed.sh — Seed all databases with sample data via db-seeder
# =============================================================================
# Writes db-seeder/.env pointing at Docker Compose hostnames, installs
# Python deps, and runs the seeder. Safe to re-run (seeder uses upserts).
# =============================================================================

WORKSPACES_DIR="/workspaces"
SEED_DIR="$WORKSPACES_DIR/db-seeder"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[seed $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[seed $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[seed $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[seed $(_ts)]${NC} ✗ $1"; }

if [ ! -d "$SEED_DIR" ]; then
  warn "db-seeder not found at $SEED_DIR — skipping"
  exit 0
fi

# =============================================================================
# 1. Write .env with Docker Compose service hostnames
# =============================================================================
# seed.py loads .env from its own directory (Path(__file__).parent / '.env').
# The committed .env.example contains localhost values — we write
# .env here with Compose service-name hostnames so the seeder can reach them.
log "Writing db-seeder .env..."
cat > "$SEED_DIR/.env" << 'EOF'
# MongoDB
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

# =============================================================================
# 2. Install Python deps in a venv (avoids polluting system Python)
# =============================================================================
log "Installing db-seeder dependencies..."
python -m venv "$SEED_DIR/.venv" 2>/dev/null || true
source "$SEED_DIR/.venv/bin/activate"
pip install -q -r "$SEED_DIR/requirements.txt"
success "db-seeder dependencies installed"

# =============================================================================
# 3. Run the seeder
# =============================================================================
log "Seeding databases..."
cd "$SEED_DIR"
if python seed.py; then
  success "Database seeding complete"
else
  warn "db-seeder exited with errors — some data may be missing (non-fatal)"
  exit 1
fi
