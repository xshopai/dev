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

# Container names are prefixed with "dev-" (set via container_name: in docker-compose.yml).
# From an external container on the same network, DNS resolves by container_name, not
# the Compose service name — so we must use the dev- prefix here.

# Run all checks in parallel
wait_for_port dev-user-mongodb     27017 "MongoDB (user)"               120 &
wait_for_port dev-product-mongodb  27017 "MongoDB (product)"            120 &
wait_for_port dev-review-mongodb   27017 "MongoDB (review)"             120 &
wait_for_port dev-audit-postgres   5432  "PostgreSQL (audit)"           120 &
wait_for_port dev-order-processor-postgres 5432 "PostgreSQL (order-processor)" 120 &
wait_for_port dev-order-sqlserver  1433  "SQL Server (order)"           180 &
wait_for_port dev-payment-sqlserver 1433 "SQL Server (payment)"        180 &
wait_for_port dev-inventory-mysql  3306  "MySQL (inventory)"            120 &
wait_for_port dev-rabbitmq         5672  "RabbitMQ"                     120 &
wait_for_port dev-redis            6379  "Redis"                         90 &
wait_for_port dev-zipkin           9411  "Zipkin"                        90 &
wait_for_port dev-mailpit          1025  "Mailpit (SMTP)"                90 &

wait

log "Infrastructure checks complete"
