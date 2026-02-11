#!/bin/bash
# =============================================================================
# xshopai - Local Development Setup Script
# =============================================================================
# This script sets up the complete local development environment:
#   1. Starts all infrastructure services (databases, messaging, tracing)
#   2. Waits for services to be healthy
#   3. Seeds initial data (optional)
#
# Usage:
#   ./setup.sh              # Start infrastructure only
#   ./setup.sh --seed       # Start infrastructure + seed data
#   ./setup.sh --clean      # Clean start (removes all data)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse arguments
SEED_DATA=false
CLEAN_START=false

for arg in "$@"; do
    case $arg in
        --seed)
            SEED_DATA=true
            shift
            ;;
        --clean)
            CLEAN_START=true
            shift
            ;;
        --help)
            echo "Usage: ./setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --seed      Seed initial data after starting services"
            echo "  --clean     Remove all existing data before starting"
            echo "  --help      Show this help message"
            exit 0
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}xshopai - Local Development Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed!${NC}"
    echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
    exit 1
fi

COMPOSE_CMD="docker-compose"
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker compose"
fi

# Clean start if requested
if [ "$CLEAN_START" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning existing data...${NC}"
    $COMPOSE_CMD down --volumes
    echo -e "${GREEN}✅ Cleaned!${NC}"
    echo ""
fi

# Start infrastructure
echo -e "${CYAN}🚀 Starting infrastructure services...${NC}"
echo ""
$COMPOSE_CMD up -d

echo ""
echo -e "${CYAN}⏳ Waiting for services to be ready...${NC}"
sleep 5

# Check service health
echo ""
echo -e "${CYAN}🔍 Checking service health...${NC}"

check_service() {
    local name=$1
    local url=$2
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $name is ready"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done

    echo -e "  ${RED}✗${NC} $name failed to start"
    return 1
}

# Check critical services
check_service "RabbitMQ" "http://localhost:15672"
check_service "Zipkin" "http://localhost:9411/health"
check_service "Mailpit" "http://localhost:8025"

echo ""
echo -e "${GREEN}✅ All infrastructure services are ready!${NC}"
echo ""

# Seed data if requested
if [ "$SEED_DATA" = true ]; then
    echo -e "${CYAN}🌱 Seeding data...${NC}"
    echo ""
    
    # Check if seed script exists
    if [ -f "../scripts/seed.sh" ]; then
        cd ../scripts
        ./seed.sh
        cd "$SCRIPT_DIR"
    else
        echo -e "${YELLOW}⚠️  Seed script not found at ../scripts/seed.sh${NC}"
        echo "You can seed data manually later."
    fi
    echo ""
fi

# Display service endpoints
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🎉 Development Environment Ready!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${CYAN}📊 Infrastructure Services:${NC}"
echo ""
echo -e "${YELLOW}Message Broker:${NC}"
echo -e "  RabbitMQ Management: ${GREEN}http://localhost:15672${NC} (admin/admin123)"
echo ""
echo -e "${YELLOW}Observability:${NC}"
echo -e "  Zipkin Tracing:      ${GREEN}http://localhost:9411${NC}"
echo ""
echo -e "${YELLOW}Cache & Session:${NC}"
echo -e "  Redis (Cart):        ${GREEN}localhost:6379${NC} (password: redis_dev_pass_123)"
echo ""
echo -e "${YELLOW}Development Tools:${NC}"
echo -e "  Mailpit (Email):     ${GREEN}http://localhost:8025${NC}"
echo ""
echo -e "${YELLOW}Databases:${NC}"
echo -e "  User MongoDB:        ${GREEN}localhost:27018${NC} (admin/admin123)"
echo -e "  Product MongoDB:     ${GREEN}localhost:27019${NC} (admin/admin123)"
echo -e "  Review MongoDB:      ${GREEN}localhost:27020${NC} (admin/admin123)"
echo -e "  Audit PostgreSQL:    ${GREEN}localhost:5434${NC} (admin/admin123)"
echo -e "  Order Processor PG:  ${GREEN}localhost:5435${NC} (postgres/postgres)"
echo -e "  Order SQL Server:    ${GREEN}localhost:1434${NC} (sa/Admin123!)"
echo -e "  Payment SQL Server:  ${GREEN}localhost:1433${NC} (sa/Admin123!)"
echo -e "  Inventory MySQL:     ${GREEN}localhost:3306${NC} (admin/admin123)"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}Next Steps:${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "1. ${CYAN}Start application services:${NC}"
echo -e "   cd ../scripts"
echo -e "   ./dev.sh              ${YELLOW}# Start all services with Dapr${NC}"
echo ""
echo -e "2. ${CYAN}Access the applications:${NC}"
echo -e "   Customer UI: ${GREEN}http://localhost:3000${NC}"
echo -e "   Admin UI:    ${GREEN}http://localhost:3001${NC}"
echo ""
echo -e "3. ${CYAN}View logs:${NC}"
echo -e "   docker-compose logs -f"
echo ""
echo -e "4. ${CYAN}Stop infrastructure:${NC}"
echo -e "   docker-compose down"
echo ""
