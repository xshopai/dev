#!/bin/bash
# =============================================================================
# 02-build.sh — Build all xshopai services (fail-soft, parallel by runtime)
# =============================================================================
# Each service writes its own log to logs/<service>.log.
# A service build failure does NOT abort the rest — all services are attempted
# and a summary table is printed at the end.
# Exit code: 0 if all passed, 1 if any failed.
# =============================================================================

WORKSPACES_DIR="/workspaces"
LOG_DIR="$WORKSPACES_DIR/dev/logs"
mkdir -p "$LOG_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[build $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[build $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[build $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[build $(_ts)]${NC} ✗ $1"; }

# Results tracking
declare -A RESULTS   # RESULTS[svc]="SUCCESS|FAILED"
declare -A TIMINGS   # TIMINGS[svc]=seconds

# -----------------------------------------------------------------------------
# build_service <name> <dir> <cmd>
#   - Runs <cmd> inside <dir>, pipes to logs/<name>.log
#   - Records result in RESULTS and TIMINGS
# -----------------------------------------------------------------------------
build_service() {
  local name="$1" dir="$2" cmd="$3"
  local log_file="$LOG_DIR/${name}.log"
  local t_start=$SECONDS

  if [ ! -d "$dir" ]; then
    warn "$name — directory $dir not found, skipping"
    RESULTS[$name]="SKIPPED"
    TIMINGS[$name]=0
    return
  fi

  ( cd "$dir" && eval "$cmd" ) >> "$log_file" 2>&1
  local exit_code=$?

  TIMINGS[$name]=$(( SECONDS - t_start ))
  if [ $exit_code -eq 0 ]; then
    RESULTS[$name]="SUCCESS"
    success "$name  (${TIMINGS[$name]}s)"
  else
    RESULTS[$name]="FAILED"
    err "$name  (${TIMINGS[$name]}s) — see $log_file"
  fi
}

# Fix NuGet directory permissions (named cache volume created as root)
mkdir -p /home/codespace/.nuget/NuGet /home/codespace/.nuget/packages 2>/dev/null || true
chmod -R 777 /home/codespace/.nuget 2>/dev/null || true

# =============================================================================
# Wave 1 — Node.js + TypeScript (fast, CPU-light — all in parallel)
# =============================================================================
log "Wave 1: Node / TypeScript services..."

NODE_SERVICES=("auth-service" "user-service" "admin-service" "audit-service" "review-service")
TS_SERVICES=("notification-service" "chat-service" "web-bff" "cart-service")
UI_SERVICES=("admin-ui" "customer-ui")

for svc in "${NODE_SERVICES[@]}"; do
  build_service "$svc" "$WORKSPACES_DIR/$svc" "npm ci --prefer-offline --no-audit 2>&1" &
done

for svc in "${TS_SERVICES[@]}"; do
  build_service "$svc" "$WORKSPACES_DIR/$svc" "npm ci --prefer-offline --no-audit && npm run build 2>&1" &
done

for svc in "${UI_SERVICES[@]}"; do
  build_service "$svc" "$WORKSPACES_DIR/$svc" "npm ci --prefer-offline --no-audit 2>&1" &
done

wait
success "Wave 1 complete"

# =============================================================================
# Wave 2 — Python (medium speed — both in parallel)
# =============================================================================
log "Wave 2: Python services..."

build_service "product-service" "$WORKSPACES_DIR/product-service" \
  "python -m venv venv && venv/bin/pip install -q -r requirements.txt 2>&1" &

build_service "inventory-service" "$WORKSPACES_DIR/inventory-service" \
  "python -m venv venv && venv/bin/pip install -q -r requirements.txt 2>&1" &

wait
success "Wave 2 complete"

# =============================================================================
# Wave 3 — .NET + Java (slow — both in parallel so they overlap)
# =============================================================================
log "Wave 3: .NET + Java services (slowest — running in parallel)..."

build_service "order-service" "$WORKSPACES_DIR/order-service" \
  "dotnet restore OrderService.sln && dotnet build OrderService.sln --no-restore -c Release 2>&1" &

build_service "payment-service" "$WORKSPACES_DIR/payment-service" \
  "dotnet restore && dotnet build --no-restore -c Release 2>&1" &

build_service "order-processor-service" "$WORKSPACES_DIR/order-processor-service" \
  "mvn -q clean package -DskipTests 2>&1" &

wait
success "Wave 3 complete"

# =============================================================================
# Summary table
# =============================================================================
echo ""
echo "  Build Results"
echo "  ─────────────────────────────────────────────────────"
printf "  %-30s %-10s %s\n" "SERVICE" "STATUS" "TIME"
echo "  ─────────────────────────────────────────────────────"

PASS=0; FAIL=0; SKIP=0
ALL_SERVICES=(
  "${NODE_SERVICES[@]}" "${TS_SERVICES[@]}" "${UI_SERVICES[@]}"
  "product-service" "inventory-service"
  "order-service" "payment-service" "order-processor-service"
)

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
