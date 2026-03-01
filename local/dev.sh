#!/bin/bash
# =============================================================================
# xshopai - Run All Services Script (Local Development)
# =============================================================================
# This script starts all microservices, BFF, and UIs in background processes
# with logs written to the dev/logs/ directory.
#
# Prerequisites:
#   - Infrastructure running: docker compose -f ../docker-compose.yml up -d
#   - Services built: ./build.sh --all
#   - .env files seeded: ./setup.sh (or manually)
#
# Usage:
#   ./dev.sh          - Start all services in background (logs to files)
#   ./dev.sh --stop   - Stop all running services

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$DEV_ROOT")"
LOG_DIR="$DEV_ROOT/logs"
PID_FILE="$SCRIPT_DIR/.service-pids"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Create logs directory
mkdir -p "$LOG_DIR"

# Function to stop all services
stop_services() {
    echo -e "${YELLOW}Stopping all services...${NC}"

    # Deregister all services from Consul first (before killing processes,
    # since kill may not propagate SIGTERM to child processes running the
    # deregister-on-shutdown handlers)
    if curl -s --max-time 2 http://localhost:8500/v1/status/leader &>/dev/null; then
        echo -e "  ${CYAN}Deregistering services from Consul...${NC}"
        SERVICE_IDS=$(curl -s http://localhost:8500/v1/agent/services | python3 -c "import sys,json; [print(k) for k in json.load(sys.stdin).keys()]" 2>/dev/null)
        for sid in $SERVICE_IDS; do
            curl -s -X PUT "http://localhost:8500/v1/agent/service/deregister/$sid" &>/dev/null
            echo -e "    Deregistered: $sid"
        done
    fi

    if [ -f "$PID_FILE" ]; then
        while read -r line; do
            name=$(echo "$line" | cut -d':' -f1)
            pid=$(echo "$line" | cut -d':' -f2)
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "  ${RED}Stopping $name (PID: $pid)${NC}"
                kill "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
        echo -e "${GREEN}All services stopped.${NC}"
    else
        echo -e "${YELLOW}No running services found.${NC}"
    fi
    exit 0
}

# Check for --stop flag
if [ "$1" = "--stop" ]; then
    stop_services
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}xshopai - Starting All Services${NC}"
echo -e "${BLUE}  (Local Development)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Services to start (ordered by port number)
declare -a SERVICES=(
    "Product Service:product-service:8001"
    "User Service:user-service:8002"
    "Admin Service:admin-service:8003"
    "Auth Service:auth-service:8004"
    "Inventory Service:inventory-service:8005"
    "Order Service:order-service:8006"
    "Order Processor:order-processor-service:8007"
    "Cart Service:cart-service:8008"
    "Payment Service:payment-service:8009"
    "Review Service:review-service:8010"
    "Notification Service:notification-service:8011"
    "Audit Service:audit-service:8012"
    "Chat Service:chat-service:8013"
    "Web BFF:web-bff:8014"
)

# UIs to start
declare -a UIS=(
    "Customer UI:customer-ui:3000"
    "Admin UI:admin-ui:3001"
)

echo -e "${CYAN}Starting services in background (logs in $LOG_DIR)${NC}"
echo ""

# Kill any existing process on a given port (prevents "port in use" errors)
kill_port() {
    local port="$1"
    local pids
    pids=$(lsof -ti:"$port" 2>/dev/null) || true
    if [ -n "$pids" ]; then
        echo -e "  ${YELLOW}Killing existing process on port $port${NC}"
        echo "$pids" | xargs kill 2>/dev/null || true
        sleep 0.5
    fi
}

# Clear previous PID file
> "$PID_FILE"

echo -e "${YELLOW}Starting backend services...${NC}"
echo ""

# Start each service
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r name path port <<< "$service_info"
    SERVICE_PATH="$WORKSPACE_ROOT/$path"
    RUN_SCRIPT="$SERVICE_PATH/scripts/dev.sh"
    LOG_FILE="$LOG_DIR/$path.log"
    
    if [ -f "$RUN_SCRIPT" ]; then
        kill_port "$port"
        echo -e "  ${GREEN}✓ Starting $name (port $port)${NC}"
        
        # Run in background, redirect output to log file
        (cd "$SERVICE_PATH" && ./scripts/dev.sh > "$LOG_FILE" 2>&1) &
        PID=$!
        echo "$name:$PID" >> "$PID_FILE"
        
        sleep 0.5
    else
        echo -e "  ${YELLOW}⚠ Skipping $name - scripts/dev.sh not found${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Starting frontend applications...${NC}"
echo ""

for ui_info in "${UIS[@]}"; do
    IFS=':' read -r name path port <<< "$ui_info"
    UI_PATH="$WORKSPACE_ROOT/$path"
    RUN_SCRIPT="$UI_PATH/scripts/dev.sh"
    LOG_FILE="$LOG_DIR/$path.log"
    
    if [ -f "$RUN_SCRIPT" ]; then
        kill_port "$port"
        echo -e "  ${GREEN}✓ Starting $name (port $port)${NC}"
        
        # Run in background, redirect output to log file
        (cd "$UI_PATH" && ./scripts/dev.sh > "$LOG_FILE" 2>&1) &
        PID=$!
        echo "$name:$PID" >> "$PID_FILE"
        
        sleep 0.5
    else
        echo -e "  ${YELLOW}⚠ Skipping $name - scripts/dev.sh not found${NC}"
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}All services are starting!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${CYAN}Service Endpoints:${NC}"
echo ""
echo -e "${WHITE}Frontend Applications:${NC}"
echo -e "${GRAY}  Customer UI:        http://localhost:3000${NC}"
echo -e "${GRAY}  Admin UI:           http://localhost:3001${NC}"
echo ""
echo -e "${WHITE}Backend for Frontend:${NC}"
echo -e "${GRAY}  Web BFF:            http://localhost:8014${NC}"
echo ""
echo -e "${WHITE}Microservices:${NC}"
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r name path port <<< "$service_info"
    if [ "$name" != "Web BFF" ]; then
        printf "${GRAY}  %-20s http://localhost:%s${NC}\n" "$name" "$port"
    fi
done
echo ""
echo -e "${GREEN}All services started.${NC}"
echo ""
echo -e "${CYAN}Useful commands:${NC}"
echo -e "${GRAY}  View logs:    tail -f $LOG_DIR/<service-name>.log${NC}"
echo -e "${GRAY}  Stop all:     ./dev.sh --stop${NC}"
echo ""
