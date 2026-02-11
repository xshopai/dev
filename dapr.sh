#!/bin/bash
# =============================================================================
# xshopai - Run All Services Script (Bash)
# =============================================================================
# This script starts all microservices, BFF, and UIs by launching their
# individual dapr scripts in separate terminal windows

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
echo -e "${BLUE}xshopai - Starting All Services${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Services to start (ordered by port number)
declare -a SERVICES=(
    "Product Service:product-service:8001:3501"
    "User Service:user-service:8002:3502"
    "Admin Service:admin-service:8003:3503"
    "Auth Service:auth-service:8004:3504"
    "Inventory Service:inventory-service:8005:3505"
    "Order Service:order-service:8006:3506"
    "Order Processor:order-processor-service:8007:3507"
    "Cart Service:cart-service:8008:3508"
    "Payment Service:payment-service:8009:3509"
    "Review Service:review-service:8010:3510"
    "Notification Service:notification-service:8011:3511"
    "Audit Service:audit-service:8012:3512"
    "Chat Service:chat-service:8013:3513"
    "Web BFF:web-bff:8014:3514"
)

# UIs to start
declare -a UIS=(
    "Customer UI:customer-ui:3000"
    "Admin UI:admin-ui:3001"
)

echo -e "${CYAN}This script will launch each service in a separate terminal window.${NC}"
echo -e "${CYAN}Each service will run with its own Dapr sidecar.${NC}"
echo ""
echo -e "${YELLOW}Each service controls its own logging output via its dapr.sh script.${NC}"
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
    IFS=':' read -r name path port dapr_port <<< "$service_info"
    SERVICE_PATH="$WORKSPACE_ROOT/$path"
    RUN_SCRIPT="$SERVICE_PATH/dapr.sh"
    
    if [ -f "$RUN_SCRIPT" ]; then
        echo -e "  ${GREEN}Starting $name...${NC}"
        
        if [ "$WINDOWS_BASH" = true ]; then
            # Windows - use mintty and filter out Dapr logs
            mintty -t "$name" -e bash -l -c "cd '$SERVICE_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'; exec bash" &
        elif [ "$OS_TYPE" = "Darwin" ]; then
            # macOS - filter Dapr logs
            osascript -e "tell app \"Terminal\" to do script \"cd '$SERVICE_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'\"" &
        else
            # Linux - filter Dapr logs
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal -- bash -c "cd '$SERVICE_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'; exec bash" &
            elif command -v xterm &> /dev/null; then
                xterm -e bash -c "cd '$SERVICE_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'; exec bash" &
            fi
        fi
        sleep 0.3
    else
        echo -e "  ${YELLOW}⚠ Skipping $name - dapr.sh not found${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Starting frontend applications...${NC}"
echo ""

for ui_info in "${UIS[@]}"; do
    IFS=':' read -r name path port <<< "$ui_info"
    UI_PATH="$WORKSPACE_ROOT/$path"
    RUN_SCRIPT="$UI_PATH/dapr.sh"
    
    if [ -f "$RUN_SCRIPT" ]; then
        echo -e "  ${GREEN}Starting $name...${NC}"
        
        if [ "$WINDOWS_BASH" = true ]; then
            # Windows - use mintty and filter out Dapr logs
            mintty -t "$name" -e bash -l -c "cd '$UI_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'; exec bash" &
        elif [ "$OS_TYPE" = "Darwin" ]; then
            # macOS - filter Dapr logs
            osascript -e "tell app \"Terminal\" to do script \"cd '$UI_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'\"" &
        else
            # Linux - filter Dapr logs
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal -- bash -c "cd '$UI_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'; exec bash" &
            elif command -v xterm &> /dev/null; then
                xterm -e bash -c "cd '$UI_PATH' && ./dapr.sh 2>&1 | grep -v '^time=' | grep -v '^level=' | grep -v 'ℹ️' | grep -v 'dapr --'; exec bash" &
            fi
        fi
        sleep 0.3
    else
        echo -e "  ${YELLOW}⚠ Skipping $name - dapr.sh not found${NC}"
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
echo -e "${GRAY}  Web BFF:            http://localhost:8080${NC}"
echo -e "${GRAY}  Web BFF (Dapr):     http://localhost:3580${NC}"
echo ""
echo -e "${WHITE}Microservices:${NC}"
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r name path port dapr_port <<< "$service_info"
    if [ "$name" != "Web BFF" ]; then
        printf "${GRAY}  %-20s http://localhost:%s" "$name" "$port"
        if [ -n "$dapr_port" ]; then
            printf " (Dapr: %s)" "$dapr_port"
        fi
        echo -e "${NC}"
    fi
done
echo ""
echo -e "${YELLOW}To stop all services, close each terminal window.${NC}"
echo ""
