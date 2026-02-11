#!/bin/bash
# =============================================================================
# xshopai - Run All Services Script (Local/No Dapr)
# =============================================================================
# This script starts all microservices, BFF, and UIs by launching their
# individual local.sh scripts in separate terminal windows
#
# WARNING: Services will run WITHOUT Dapr sidecars
# - Event publishing will fail (logged but services continue)
# - Service-to-service communication won't work
# - Event consumption won't work
# Use this for isolated development/testing only!

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}xshopai - Starting All Services (Local)${NC}"
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

echo -e "${RED}⚠️  WARNING: Running WITHOUT Dapr${NC}"
echo -e "${YELLOW}This mode is for isolated development only.${NC}"
echo -e "${YELLOW}Event publishing, service-to-service calls, and event consumption will fail.${NC}"
echo ""
echo -e "${CYAN}This script will launch each service in a separate terminal window.${NC}"
echo ""
echo -e "${GREEN}Press Enter to start all services...${NC}"
read

echo ""
echo -e "${YELLOW}Starting backend services...${NC}"
echo ""

# Detect operating system
OS_TYPE="$(uname -s)"
case "${OS_TYPE}" in
    CYGWIN*|MINGW*|MSYS*)
        WINDOWS_BASH=true
        ;;
    *)
        WINDOWS_BASH=false
        ;;
esac

# Start each service
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r name path port <<< "$service_info"
    SERVICE_PATH="$WORKSPACE_ROOT/$path"
    RUN_SCRIPT="$SERVICE_PATH/scripts/local.sh"
    
    if [ -f "$RUN_SCRIPT" ]; then
        echo -e "  ${GREEN}Starting $name...${NC}"
        
        if [ "$WINDOWS_BASH" = true ]; then
            # Windows - use mintty
            mintty -t "$name (Local)" -e bash -l -c "cd '$SERVICE_PATH' && ./scripts/local.sh; exec bash" &
        elif [ "$OS_TYPE" = "Darwin" ]; then
            # macOS
            osascript -e "tell app \"Terminal\" to do script \"cd '$SERVICE_PATH' && ./scripts/local.sh\"" &
        else
            # Linux
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal --title="$name (Local)" -- bash -c "cd '$SERVICE_PATH' && ./scripts/local.sh; exec bash" &
            elif command -v xterm &> /dev/null; then
                xterm -T "$name (Local)" -e bash -c "cd '$SERVICE_PATH' && ./scripts/local.sh; exec bash" &
            fi
        fi
        sleep 0.3
    else
        echo -e "  ${YELLOW}⚠ Skipping $name - scripts/local.sh not found${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Starting frontend applications...${NC}"
echo ""

for ui_info in "${UIS[@]}"; do
    IFS=':' read -r name path port <<< "$ui_info"
    UI_PATH="$WORKSPACE_ROOT/$path"
    RUN_SCRIPT="$UI_PATH/scripts/local.sh"
    
    if [ -f "$RUN_SCRIPT" ]; then
        echo -e "  ${GREEN}Starting $name...${NC}"
        
        if [ "$WINDOWS_BASH" = true ]; then
            # Windows - use mintty
            mintty -t "$name (Local)" -e bash -l -c "cd '$UI_PATH' && ./scripts/local.sh; exec bash" &
        elif [ "$OS_TYPE" = "Darwin" ]; then
            # macOS
            osascript -e "tell app \"Terminal\" to do script \"cd '$UI_PATH' && ./scripts/local.sh\"" &
        else
            # Linux
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal --title="$name (Local)" -- bash -c "cd '$UI_PATH' && ./scripts/local.sh; exec bash" &
            elif command -v xterm &> /dev/null; then
                xterm -T "$name (Local)" -e bash -c "cd '$UI_PATH' && ./scripts/local.sh; exec bash" &
            fi
        fi
        sleep 0.3
    else
        echo -e "  ${YELLOW}⚠ Skipping $name - scripts/local.sh not found${NC}"
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
echo -e "${RED}⚠️  REMINDER: Running without Dapr - inter-service communication disabled${NC}"
echo -e "${YELLOW}To stop all services, close each terminal window.${NC}"
echo ""
