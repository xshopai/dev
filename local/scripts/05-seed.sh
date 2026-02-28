#!/bin/bash
# =============================================================================
# 05-seed.sh — Seed all databases with sample data via db-seeder
# =============================================================================
# Writes db-seeder/.env pointing at localhost with host-mapped ports, installs
# Python deps, and runs the seeder. Safe to re-run (seeder uses upserts).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(dirname "$SCRIPT_DIR")"
DEV_ROOT="$(dirname "$LOCAL_DIR")"
WORKSPACE_ROOT="$(dirname "$DEV_ROOT")"
SEED_DIR="$WORKSPACE_ROOT/db-seeder"

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
# 1. Write .env with localhost + host-mapped ports
# =============================================================================
# seed.py loads .env from its own directory (Path(__file__).parent / '.env').
# For local dev, all databases are on localhost with host-mapped ports.
log "Writing db-seeder .env (localhost)..."
cat > "$SEED_DIR/.env" << 'EOF'
# MongoDB — host-mapped ports
USER_MONGODB_URI=mongodb://admin:admin123@localhost:27018/user_service_db?authSource=admin
PRODUCT_MONGODB_URI=mongodb://admin:admin123@localhost:27019/product_service_db?authSource=admin
REVIEW_MONGODB_URI=mongodb://admin:admin123@localhost:27020/review_service_db?authSource=admin

# PostgreSQL — audit-service (host-mapped port 5434)
POSTGRES_HOST=localhost
POSTGRES_PORT=5434
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=audit_service_db

# MySQL — inventory-service (host-mapped port 3306)
MYSQL_SERVER_CONNECTION=mysql+pymysql://admin:admin123@localhost:3306
INVENTORY_DB_NAME=inventory_service_db

# SQL Server — order-service (host-mapped port 1434)
ORDER_SQLSERVER_HOST=localhost
ORDER_SQLSERVER_PORT=1434
ORDER_SQLSERVER_USER=sa
ORDER_SQLSERVER_PASSWORD=Admin123!
ORDER_SQLSERVER_DB=order_service_db

# SQL Server — payment-service (host-mapped port 1433)
PAYMENT_SQLSERVER_HOST=localhost
PAYMENT_SQLSERVER_PORT=1433
PAYMENT_SQLSERVER_USER=sa
PAYMENT_SQLSERVER_PASSWORD=Admin123!
PAYMENT_SQLSERVER_DB=payment_service_db

# Redis — cart-service (host-mapped port 6379)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis_dev_pass_123
EOF
success "db-seeder .env written"

# =============================================================================
# 2. Install Python deps in a venv
# =============================================================================
log "Installing db-seeder dependencies..."

# Cross-platform venv creation (Linux/macOS use python3, Windows Git Bash may use python)
if command -v python3 &>/dev/null; then
  PYTHON_CMD="python3"
else
  PYTHON_CMD="python"
fi

$PYTHON_CMD -m venv "$SEED_DIR/.venv" 2>/dev/null || true

# Cross-platform venv activation (Linux/macOS vs Windows Git Bash)
if [ -f "$SEED_DIR/.venv/bin/activate" ]; then
  source "$SEED_DIR/.venv/bin/activate"
elif [ -f "$SEED_DIR/.venv/Scripts/activate" ]; then
  source "$SEED_DIR/.venv/Scripts/activate"
else
  warn "Could not activate venv — trying system Python"
fi

pip install -q -r "$SEED_DIR/requirements.txt"
success "db-seeder dependencies installed"

# =============================================================================
# 3. Run the seeder
# =============================================================================
log "Seeding databases..."
cd "$SEED_DIR"
if $PYTHON_CMD seed.py; then
  success "Database seeding complete"
else
  warn "db-seeder exited with errors — some data may be missing (non-fatal)"
  exit 1
fi
