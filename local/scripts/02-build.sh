#!/bin/bash
# =============================================================================
# 02-build.sh — Build all xshopai services (fail-soft, one at a time)
# =============================================================================
# Each service is built sequentially in a flat list. Build failures do NOT
# abort the rest — all services are attempted and a summary table is printed.
# Exit code: 0 if all passed, 1 if any failed.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(dirname "$SCRIPT_DIR")"
DEV_ROOT="$(dirname "$LOCAL_DIR")"
WORKSPACE_ROOT="$(dirname "$DEV_ROOT")"
LOG_DIR="$DEV_ROOT/logs"
mkdir -p "$LOG_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[build $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[build $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[build $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[build $(_ts)]${NC} ✗ $1"; }

# Results tracking
RESULTS_DIR="/tmp/xshopai-build-results-local"
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# build_service <name> <dir> <cmd>
build_service() {
  local name="$1" dir="$2" cmd="$3"
  local log_file="$LOG_DIR/${name}-build.log"
  local t_start=$SECONDS

  if [ ! -d "$dir" ]; then
    warn "$name — directory $dir not found, skipping"
    echo "SKIPPED 0" > "$RESULTS_DIR/$name"
    return
  fi

  ( cd "$dir" && eval "$cmd" ) >> "$log_file" 2>&1
  local exit_code=$?
  local elapsed=$(( SECONDS - t_start ))

  if [ $exit_code -eq 0 ]; then
    echo "SUCCESS $elapsed" > "$RESULTS_DIR/$name"
    success "$name  (${elapsed}s)"
  else
    echo "FAILED $elapsed" > "$RESULTS_DIR/$name"
    err "$name  (${elapsed}s) — see $log_file"
  fi
}

# =============================================================================
# Flat service list — built one at a time, in order
# =============================================================================
ALL_SERVICES=(
  "auth-service"
  "user-service"
  "admin-service"
  "audit-service"
  "review-service"
  "notification-service"
  "chat-service"
  "web-bff"
  "cart-service"
  "admin-ui"
  "customer-ui"
  "product-service"
  "inventory-service"
  "order-service"
  "payment-service"
  "order-processor-service"
)

# Build commands per service (keyed by name)
declare -A BUILD_CMD
BUILD_CMD["auth-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["user-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["admin-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["audit-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["review-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["notification-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["chat-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["web-bff"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["cart-service"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["admin-ui"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["customer-ui"]="npm ci --prefer-offline --no-audit 2>&1"
BUILD_CMD["product-service"]="python3 -m venv venv && venv/bin/pip install -q -r requirements.txt 2>&1 || python -m venv venv && venv/Scripts/pip install -q -r requirements.txt 2>&1"
BUILD_CMD["inventory-service"]="python3 -m venv venv && venv/bin/pip install -q -r requirements.txt 2>&1 || python -m venv venv && venv/Scripts/pip install -q -r requirements.txt 2>&1"
BUILD_CMD["order-service"]="dotnet restore OrderService.sln && dotnet build OrderService.sln --no-restore -c Release 2>&1"
BUILD_CMD["payment-service"]="dotnet restore PaymentService/PaymentService.csproj && dotnet build PaymentService/PaymentService.csproj --no-restore -c Release 2>&1"
BUILD_CMD["order-processor-service"]="mvn -q clean package -DskipTests 2>&1"

TOTAL=${#ALL_SERVICES[@]}
CURRENT=0

for svc in "${ALL_SERVICES[@]}"; do
  (( CURRENT++ )) || true
  log "[$CURRENT/$TOTAL] Building $svc..."
  build_service "$svc" "$WORKSPACE_ROOT/$svc" "${BUILD_CMD[$svc]}"
done

declare -A RESULTS TIMINGS
for svc in "${ALL_SERVICES[@]}"; do
  f="$RESULTS_DIR/$svc"
  if [ -f "$f" ]; then
    read -r status time < "$f"
    RESULTS[$svc]=$status
    TIMINGS[$svc]=$time
  fi
done

echo ""
echo "  Build Results"
echo "  ─────────────────────────────────────────────────────"
printf "  %-30s %-10s %s\n" "SERVICE" "STATUS" "TIME"
echo "  ─────────────────────────────────────────────────────"

PASS=0; FAIL=0; SKIP=0
for svc in "${ALL_SERVICES[@]}"; do
  status="${RESULTS[$svc]:-UNKNOWN}"
  time="${TIMINGS[$svc]:-?}s"
  case "$status" in
    SUCCESS) printf "  %-30s ${GREEN}%-10s${NC} %s\n" "$svc" "✓ $status" "$time"; (( PASS++ )) || true ;;
    FAILED)  printf "  %-30s ${RED}%-10s${NC} %s\n"   "$svc" "✗ $status" "$time"; (( FAIL++ )) || true ;;
    SKIPPED) printf "  %-30s ${YELLOW}%-10s${NC} %s\n" "$svc" "⚠ $status" "$time"; (( SKIP++ )) || true ;;
    *)       printf "  %-30s ${YELLOW}%-10s${NC} %s\n" "$svc" "? $status"  "$time" ;;
  esac
done

echo "  ─────────────────────────────────────────────────────"
echo -e "  ${GREEN}✓ $PASS passed${NC}  ${RED}✗ $FAIL failed${NC}  ${YELLOW}⚠ $SKIP skipped${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
  err "$FAIL service(s) failed to build — check logs in $LOG_DIR/"
  exit 1
fi
