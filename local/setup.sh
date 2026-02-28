#!/bin/bash
# =============================================================================
# xshopai Local Development Setup Script
# =============================================================================
# Orchestrates a complete local development environment setup:
#   1. Checks prerequisites (Docker, Node.js, Python, Java, .NET)
#   2. Clones all service repositories (if not already present)
#   3. Starts infrastructure (Docker Compose)
#   4. Seeds .env / config files for all services
#   5. Builds all services
#   6. Seeds databases (optional)
#
# Usage:
#   ./setup.sh                 Full setup (no DB seeding)
#   ./setup.sh --seed          Full setup + seed databases
#   ./setup.sh --skip-build    Skip the build step
#   ./setup.sh --infra-only    Only start infrastructure
#
# Prerequisites:
#   Docker Desktop (Windows/Mac) or Docker Engine (Linux)
#   Node.js 18+, Python 3.12+, Java 17+, .NET 8 SDK
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$DEV_ROOT")"
LOG_DIR="$DEV_ROOT/logs"
COMPOSE_FILE="$DEV_ROOT/docker-compose.yml"

mkdir -p "$LOG_DIR"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[setup $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[setup $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[setup $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[setup $(_ts)]${NC} ✗ $1"; }

# Parse arguments
SEED_DB=false
SKIP_BUILD=false
INFRA_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --seed)       SEED_DB=true; shift ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        --infra-only) INFRA_ONLY=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--seed] [--skip-build] [--infra-only]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   xshopai Platform — Local Setup          ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

START_TIME=$SECONDS

# =============================================================================
# Step 1: Check Prerequisites
# =============================================================================
log "▶ Step 1: Checking prerequisites..."

MISSING=()

if ! command -v docker &>/dev/null; then MISSING+=("Docker"); fi
if ! command -v docker compose &>/dev/null && ! command -v docker-compose &>/dev/null; then MISSING+=("Docker Compose"); fi
if ! command -v node &>/dev/null; then MISSING+=("Node.js 18+"); fi
if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then MISSING+=("Python 3.12+"); fi
if ! command -v java &>/dev/null; then MISSING+=("Java 17+"); fi
if ! command -v dotnet &>/dev/null; then MISSING+=(".NET 8 SDK"); fi
if ! command -v git &>/dev/null; then MISSING+=("Git"); fi

if [ ${#MISSING[@]} -gt 0 ]; then
    err "Missing prerequisites: ${MISSING[*]}"
    echo -e "  ${YELLOW}Please install the missing tools and re-run this script.${NC}"
    echo -e "  ${GRAY}See local/README.md for installation links.${NC}"
    exit 1
fi

# Show versions
success "Prerequisites OK"
echo -e "  ${GRAY}Docker:  $(docker --version 2>/dev/null | head -1)${NC}"
echo -e "  ${GRAY}Node.js: $(node --version 2>/dev/null)${NC}"
echo -e "  ${GRAY}Python:  $(python3 --version 2>/dev/null || python --version 2>/dev/null)${NC}"
echo -e "  ${GRAY}Java:    $(java -version 2>&1 | head -1)${NC}"
echo -e "  ${GRAY}.NET:    $(dotnet --version 2>/dev/null)${NC}"
echo ""

# =============================================================================
# Step 2: Clone Repositories
# =============================================================================
log "▶ Step 2: Cloning repositories..."

REPOS=(
    admin-service admin-ui audit-service auth-service
    cart-service chat-service customer-ui
    inventory-service notification-service
    order-processor-service order-service payment-service
    product-service review-service user-service web-bff
    db-seeder
)

CLONE_COUNT=0
SKIP_COUNT=0
for repo in "${REPOS[@]}"; do
    REPO_PATH="$WORKSPACE_ROOT/$repo"
    if [ -d "$REPO_PATH/.git" ]; then
        (( SKIP_COUNT++ )) || true
    else
        log "  Cloning $repo..."
        git clone "https://github.com/xshopai/$repo.git" "$REPO_PATH" 2>/dev/null || {
            warn "  Failed to clone $repo — continuing"
            continue
        }
        (( CLONE_COUNT++ )) || true
    fi
done

success "Repositories: $CLONE_COUNT cloned, $SKIP_COUNT already present"
echo ""

# =============================================================================
# Step 3: Start Infrastructure
# =============================================================================
log "▶ Step 3: Starting infrastructure (Docker Compose)..."

if [ ! -f "$COMPOSE_FILE" ]; then
    err "docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

cd "$DEV_ROOT"
docker compose -f "$COMPOSE_FILE" up -d 2>&1 | tail -5
success "Infrastructure containers started"
echo ""

# Wait for key services to be healthy
log "  Waiting for services to be ready..."

wait_for_port() {
    local name="$1" host="$2" port="$3" max_wait="${4:-60}"
    local elapsed=0
    while ! docker compose -f "$COMPOSE_FILE" exec -T "$host" true 2>/dev/null; do
        sleep 2; elapsed=$((elapsed + 2))
        if [ $elapsed -ge $max_wait ]; then
            warn "$name not ready after ${max_wait}s"
            return 1
        fi
    done
    success "  $name ready"
}

# Quick health checks — just verify the containers are running
INFRA_SERVICES=(rabbitmq redis user-mongodb product-mongodb review-mongodb audit-postgres order-processor-postgres order-sqlserver payment-sqlserver inventory-mysql zipkin mailpit)
ALL_UP=true
for svc in "${INFRA_SERVICES[@]}"; do
    if docker compose -f "$COMPOSE_FILE" ps --status running "$svc" 2>/dev/null | grep -q "$svc"; then
        success "  $svc running"
    else
        warn "  $svc not running"
        ALL_UP=false
    fi
done

if [ "$ALL_UP" = true ]; then
    success "All infrastructure services are running"
else
    warn "Some infrastructure services may not be ready yet — check with: docker compose ps"
fi
echo ""

if [ "$INFRA_ONLY" = true ]; then
    echo -e "${GREEN}Infrastructure is up! Exiting (--infra-only).${NC}"
    exit 0
fi

# =============================================================================
# Step 4: Seed .env / Config Files
# =============================================================================
log "▶ Step 4: Seeding .env and config files..."

# Copy dev/.env.example → dev/.env (if not exists)
if [ ! -f "$DEV_ROOT/.env" ]; then
    cp "$DEV_ROOT/.env.example" "$DEV_ROOT/.env" 2>/dev/null && success "dev/.env created" || warn "dev/.env.example not found"
else
    success "dev/.env already exists"
fi

# Node / TypeScript / Python services: .env.http or .env.example → .env
# Local dev uses localhost with host-mapped ports — no hostname patching needed.
seed_env_local() {
    local svc="$1"
    local target="$WORKSPACE_ROOT/$svc/.env"
    local http="$WORKSPACE_ROOT/$svc/.env.http"
    local example="$WORKSPACE_ROOT/$svc/.env.example"

    if [ -f "$target" ]; then
        success "  $svc  (.env exists)"
        return
    fi

    if [ -f "$http" ]; then
        cp "$http" "$target"
        success "  $svc  (.env.http → .env)"
    elif [ -f "$example" ]; then
        cp "$example" "$target"
        success "  $svc  (.env.example → .env)"
    else
        warn "  $svc — no .env template found"
    fi
}

ENV_SERVICES=(
    admin-service audit-service auth-service
    cart-service chat-service
    inventory-service notification-service
    product-service review-service
    user-service web-bff
    admin-ui customer-ui
)
for svc in "${ENV_SERVICES[@]}"; do
    seed_env_local "$svc"
done

# .NET services: appsettings.Http.json → appsettings.Development.json
# For local dev, we keep localhost values (no hostname patching).
ORDER_HTTP="$WORKSPACE_ROOT/order-service/OrderService.Api/appsettings.Http.json"
ORDER_DEV="$WORKSPACE_ROOT/order-service/OrderService.Api/appsettings.Development.json"
if [ -f "$ORDER_HTTP" ] && [ ! -f "$ORDER_DEV" ]; then
    cp "$ORDER_HTTP" "$ORDER_DEV"
    success "  order-service  (appsettings.Http.json → Development.json)"
elif [ -f "$ORDER_DEV" ]; then
    success "  order-service  (appsettings.Development.json exists)"
else
    warn "  order-service  appsettings.Http.json not found"
fi

PAYMENT_HTTP="$WORKSPACE_ROOT/payment-service/PaymentService/appsettings.Http.json"
PAYMENT_DEV="$WORKSPACE_ROOT/payment-service/PaymentService/appsettings.Development.json"
if [ -f "$PAYMENT_HTTP" ] && [ ! -f "$PAYMENT_DEV" ]; then
    cp "$PAYMENT_HTTP" "$PAYMENT_DEV"
    success "  payment-service  (appsettings.Http.json → Development.json)"
elif [ -f "$PAYMENT_DEV" ]; then
    success "  payment-service  (appsettings.Development.json exists)"
else
    warn "  payment-service  appsettings.Http.json not found"
fi

# Java service: application-http.yml → application-dev.yml
OPS_HTTP="$WORKSPACE_ROOT/order-processor-service/src/main/resources/application-http.yml"
OPS_DEV="$WORKSPACE_ROOT/order-processor-service/src/main/resources/application-dev.yml"
if [ -f "$OPS_HTTP" ] && [ ! -f "$OPS_DEV" ]; then
    cp "$OPS_HTTP" "$OPS_DEV"
    success "  order-processor-service  (application-http.yml → application-dev.yml)"
elif [ -f "$OPS_DEV" ]; then
    success "  order-processor-service  (application-dev.yml exists)"
else
    warn "  order-processor-service  application-http.yml not found"
fi

echo ""

# =============================================================================
# Step 5: Build All Services
# =============================================================================
if [ "$SKIP_BUILD" = true ]; then
    warn "Skipping build (--skip-build)"
else
    log "▶ Step 5: Building all services..."
    if [ -x "$SCRIPT_DIR/build.sh" ]; then
        bash "$SCRIPT_DIR/build.sh" --all --sequential 2>&1 | tee "$LOG_DIR/build.log"
        success "Build complete (see $LOG_DIR/build.log)"
    else
        warn "build.sh not found — skipping build"
    fi
fi
echo ""

# =============================================================================
# Step 6: Seed Databases (optional)
# =============================================================================
if [ "$SEED_DB" = true ]; then
    log "▶ Step 6: Seeding databases..."
    SEED_DIR="$WORKSPACE_ROOT/db-seeder/seed"
    if [ -d "$SEED_DIR" ] && [ -f "$SEED_DIR/run.sh" ]; then
        cd "$SEED_DIR"
        bash run.sh 2>&1 | tee "$LOG_DIR/seed.log"
        success "Database seeding complete"
    else
        warn "db-seeder/seed/run.sh not found — skipping"
    fi
else
    log "Skipping database seeding (use --seed to enable)"
fi
echo ""

# =============================================================================
# Summary
# =============================================================================
TOTAL=$(( SECONDS - START_TIME ))

echo -e "${CYAN}  ═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Local setup complete in ${TOTAL}s${NC}"
echo -e "${CYAN}  ═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${WHITE}Getting started:${NC}"
echo -e "  ${GRAY}Start all services:${NC}    cd $(basename "$SCRIPT_DIR") && ./dev.sh"
echo -e "  ${GRAY}Stop all services:${NC}     cd $(basename "$SCRIPT_DIR") && ./dev.sh --stop"
echo -e "  ${GRAY}Build a service:${NC}       cd $(basename "$SCRIPT_DIR") && ./build.sh <service-name>"
echo -e "  ${GRAY}View service logs:${NC}     tail -f $LOG_DIR/<service>.log"
echo -e "  ${GRAY}Stop infrastructure:${NC}   docker compose -f $COMPOSE_FILE down"
echo ""
echo -e "  ${CYAN}Service Endpoints:${NC}"
echo -e "  ${GRAY}Customer UI:   http://localhost:3000${NC}"
echo -e "  ${GRAY}Admin UI:      http://localhost:3001${NC}"
echo -e "  ${GRAY}Web BFF:       http://localhost:8014${NC}"
echo -e "  ${GRAY}RabbitMQ UI:   http://localhost:15672  (admin/admin123)${NC}"
echo -e "  ${GRAY}Zipkin:        http://localhost:9411${NC}"
echo -e "  ${GRAY}Mailpit:       http://localhost:8025${NC}"
echo ""
