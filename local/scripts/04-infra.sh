#!/bin/bash
# =============================================================================
# 04-infra.sh — Start Docker Compose infrastructure and verify health
# =============================================================================
# For LOCAL development — starts docker compose services and polls each port
# on localhost with host-mapped ports until it accepts a TCP connection (or
# times out). Logs a warning and continues rather than aborting if a service
# is slow.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(dirname "$SCRIPT_DIR")"
DEV_ROOT="$(dirname "$LOCAL_DIR")"
COMPOSE_FILE="$DEV_ROOT/docker-compose.yml"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[infra $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[infra $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[infra $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[infra $(_ts)]${NC} ✗ $1"; }

# =============================================================================
# 1. Start Docker Compose
# =============================================================================
if [ ! -f "$COMPOSE_FILE" ]; then
  err "docker-compose.yml not found at $COMPOSE_FILE"
  exit 1
fi

log "Starting infrastructure (docker compose up -d)..."
cd "$DEV_ROOT"
docker compose -f "$COMPOSE_FILE" up -d 2>&1 | tail -5
success "Docker Compose started"

# =============================================================================
# 2. Health-check all services via localhost + host-mapped ports
# =============================================================================

# wait_for_port <host> <port> <label> [max_seconds]
# Use bash /dev/tcp as a portable alternative to nc (which may not be installed
# on Windows Git Bash).
wait_for_port() {
  local host="$1" port="$2" label="$3" max="${4:-60}"
  local elapsed=0
  while true; do
    # Try bash built-in, fall back to nc, fall back to docker compose ps
    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
      break
    elif command -v nc &>/dev/null && nc -z "$host" "$port" 2>/dev/null; then
      break
    fi
    if [ "$elapsed" -ge "$max" ]; then
      warn "$label not ready after ${max}s — continuing anyway"
      return 1
    fi
    sleep 2
    (( elapsed += 2 )) || true
  done
  success "$label  (ready in ${elapsed}s)"
}

log "Checking infrastructure health (localhost ports)..."

# Local dev uses host-mapped ports (defined in docker-compose.yml).
# Run all checks in parallel, collect PIDs to check exit codes.
declare -A CHECK_PIDS
wait_for_port localhost 27018 "MongoDB (user)"               120 & CHECK_PIDS[$!]="MongoDB (user)"
wait_for_port localhost 27019 "MongoDB (product)"            120 & CHECK_PIDS[$!]="MongoDB (product)"
wait_for_port localhost 27020 "MongoDB (review)"             120 & CHECK_PIDS[$!]="MongoDB (review)"
wait_for_port localhost 5434  "PostgreSQL (audit)"           120 & CHECK_PIDS[$!]="PostgreSQL (audit)"
wait_for_port localhost 5435  "PostgreSQL (order-processor)" 120 & CHECK_PIDS[$!]="PostgreSQL (order-processor)"
wait_for_port localhost 1434  "SQL Server (order)"           180 & CHECK_PIDS[$!]="SQL Server (order)"
wait_for_port localhost 1433  "SQL Server (payment)"         180 & CHECK_PIDS[$!]="SQL Server (payment)"
wait_for_port localhost 3306  "MySQL (inventory)"            120 & CHECK_PIDS[$!]="MySQL (inventory)"
wait_for_port localhost 5672  "RabbitMQ"                     120 & CHECK_PIDS[$!]="RabbitMQ"
wait_for_port localhost 6379  "Redis"                         90 & CHECK_PIDS[$!]="Redis"
wait_for_port localhost 9411  "Zipkin"                        90 & CHECK_PIDS[$!]="Zipkin"
wait_for_port localhost 1025  "Mailpit (SMTP)"                90 & CHECK_PIDS[$!]="Mailpit (SMTP)"

# Wait for all and track failures
INFRA_FAILURES=0
for pid in "${!CHECK_PIDS[@]}"; do
  if ! wait "$pid"; then
    (( INFRA_FAILURES++ )) || true
  fi
done

log "Infrastructure checks complete"

if [ "$INFRA_FAILURES" -gt 0 ]; then
  err "$INFRA_FAILURES service(s) not ready — some steps may fail"
  exit 1
fi
