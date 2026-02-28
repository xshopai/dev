#!/bin/bash
# =============================================================================
# 04-infra.sh — Verify shared infrastructure containers are healthy
# =============================================================================
# Polls each port until it accepts a TCP connection (or times out).
# Logs a warning and continues rather than aborting if a service is slow.
# =============================================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[infra $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[infra $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[infra $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[infra $(_ts)]${NC} ✗ $1"; }

# wait_for_port <host> <port> <label> [max_seconds]
wait_for_port() {
  local host="$1" port="$2" label="$3" max="${4:-60}"
  local elapsed=0
  while ! nc -z "$host" "$port" 2>/dev/null; do
    if [ "$elapsed" -ge "$max" ]; then
      warn "$label not ready after ${max}s — continuing anyway"
      return 1
    fi
    sleep 2
    (( elapsed += 2 )) || true
  done
  success "$label  (ready in ${elapsed}s)"
}

log "Checking infrastructure health..."

# Use Compose service names (not container_name "dev-*" prefix).  Both resolve
# on the xshopai-dev network; bare names match remoteEnv in devcontainer.json.

# Run all checks in parallel, collect PIDs to check exit codes.
declare -A CHECK_PIDS
wait_for_port user-mongodb     27017 "MongoDB (user)"               120 & CHECK_PIDS[$!]="MongoDB (user)"
wait_for_port product-mongodb  27017 "MongoDB (product)"            120 & CHECK_PIDS[$!]="MongoDB (product)"
wait_for_port review-mongodb   27017 "MongoDB (review)"             120 & CHECK_PIDS[$!]="MongoDB (review)"
wait_for_port audit-postgres   5432  "PostgreSQL (audit)"           120 & CHECK_PIDS[$!]="PostgreSQL (audit)"
wait_for_port order-processor-postgres 5432 "PostgreSQL (order-processor)" 120 & CHECK_PIDS[$!]="PostgreSQL (order-processor)"
wait_for_port order-sqlserver  1433  "SQL Server (order)"           180 & CHECK_PIDS[$!]="SQL Server (order)"
wait_for_port payment-sqlserver 1433 "SQL Server (payment)"        180 & CHECK_PIDS[$!]="SQL Server (payment)"
wait_for_port inventory-mysql  3306  "MySQL (inventory)"            120 & CHECK_PIDS[$!]="MySQL (inventory)"
wait_for_port rabbitmq         5672  "RabbitMQ"                     120 & CHECK_PIDS[$!]="RabbitMQ"
wait_for_port redis            6379  "Redis"                         90 & CHECK_PIDS[$!]="Redis"
wait_for_port zipkin           9411  "Zipkin"                        90 & CHECK_PIDS[$!]="Zipkin"
wait_for_port mailpit          1025  "Mailpit (SMTP)"                90 & CHECK_PIDS[$!]="Mailpit (SMTP)"

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
