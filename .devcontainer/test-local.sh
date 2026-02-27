#!/bin/bash
# =============================================================================
# test-local.sh — Run Codespace setup locally inside a Docker container
# =============================================================================
# Simulates a GitHub Codespace by mounting all locally-cloned repos into the
# same devcontainer image used in production.  The infra Docker Compose stack
# (Mongo, Redis, RabbitMQ, SQL Server, etc.) must already be running.
#
# Usage:
#   bash .devcontainer/test-local.sh              # full setup.sh
#   bash .devcontainer/test-local.sh --step 3     # run only 03-env.sh
#   bash .devcontainer/test-local.sh --shell       # drop into bash for manual testing
#   bash .devcontainer/test-local.sh --skip-build  # skip slow build step
#
# Pre-requisites:
#   cd dev && docker compose up -d              # start infra stack
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
IMAGE="mcr.microsoft.com/devcontainers/universal:2"
NETWORK="xshopai-dev-network"
SCRIPTS_MOUNT="/workspaces/dev/.devcontainer/scripts"

# Detect the host path of the xshopai workspace root
# This script lives at dev/.devcontainer/test-local.sh
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$SCRIPT_PATH"
DEV_DIR="$(dirname "$SCRIPT_PATH")"
WORKSPACE_ROOT="$(dirname "$DEV_DIR")"   # e.g. /c/gh/xshopai  or  c:/gh/xshopai

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
RED='\033[0;31m';   CYAN='\033[0;36m';   NC='\033[0m'
log()     { echo -e "${BLUE}[test-local]${NC} $1"; }
success() { echo -e "${GREEN}[test-local]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[test-local]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[test-local]${NC} ✗ $1"; exit 1; }

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
STEP=""
SHELL_MODE=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step)       STEP="$2"; shift 2 ;;
    --step=*)     STEP="${1#*=}"; shift ;;
    --shell)      SHELL_MODE=true; shift ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    -h|--help)
      echo ""
      echo "Usage: bash .devcontainer/test-local.sh [options]"
      echo ""
      echo "  (no args)          Run full setup.sh (all 6 steps)"
      echo "  --step N           Run only step N (1=clone 2=build 3=env 4=infra 5=seed 6=start)"
      echo "  --skip-build       Run setup.sh but skip step 2 (build) — fast iteration"
      echo "  --shell            Drop into an interactive bash shell in the container"
      echo ""
      echo "Pre-requisites:"
      echo "  cd dev && docker compose up -d"
      echo ""
      exit 0
      ;;
    *) err "Unknown argument: $1 (use --help)" ;;
  esac
done

# ---------------------------------------------------------------------------
# Verify infra is running
# ---------------------------------------------------------------------------
log "Checking infra containers..."
if ! docker network inspect "$NETWORK" > /dev/null 2>&1; then
  err "Docker network '$NETWORK' not found.\nRun:  cd $DEV_DIR && docker compose up -d"
fi

if ! docker ps --format '{{.Names}}' | grep -q 'rabbitmq\|redis\|mongodb'; then
  warn "Infra containers may not be running — start them first:"
  warn "  cd $DEV_DIR && docker compose up -d"
  echo ""
fi
success "Network $NETWORK exists"

# ---------------------------------------------------------------------------
# Pull image if needed (silent if already cached)
# ---------------------------------------------------------------------------
log "Ensuring image is available: $IMAGE"
docker image inspect "$IMAGE" > /dev/null 2>&1 || {
  warn "Image not cached — pulling (this takes a few minutes the first time)..."
  docker pull "$IMAGE"
}
success "Image ready"

# ---------------------------------------------------------------------------
# Build the docker run command
# ---------------------------------------------------------------------------
DOCKER_ARGS=(
  "run" "--rm"
  # Mount all repos at /workspaces (same layout as a Codespace)
  "-v" "${WORKSPACE_ROOT}:/workspaces"
  # Join the infra network so container can reach MongoDB, Redis, etc. by name
  "--network" "$NETWORK"
  # Simulate Codespace env vars that services expect
  "-e" "CODESPACES=true"
  "-e" "NODE_ENV=development"
  "-e" "SERVICE_INVOCATION_MODE=http"
  "-e" "RABBITMQ_HOST=rabbitmq"
  "-e" "RABBITMQ_PORT=5672"
  "-e" "RABBITMQ_USER=admin"
  "-e" "RABBITMQ_PASSWORD=admin123"
  "-e" "REDIS_HOST=redis"
  "-e" "REDIS_PORT=6379"
  "-e" "REDIS_PASSWORD=redis_dev_pass_123"
  "-e" "ZIPKIN_URL=http://zipkin:9411"
  "-e" "MAILPIT_SMTP_HOST=mailpit"
  "-e" "MAILPIT_SMTP_PORT=1025"
)

# ---------------------------------------------------------------------------
# Determine what to run in the container
# ---------------------------------------------------------------------------
if [ "$SHELL_MODE" = true ]; then
  log "Dropping into interactive shell..."
  log "  Repos are at /workspaces/*"
  log "  Scripts are at $SCRIPTS_MOUNT/"
  DOCKER_ARGS+=("-it" "$IMAGE" "bash")

elif [ -n "$STEP" ]; then
  # Map step number to script filename
  case "$STEP" in
    1) SCRIPT="01-clone.sh" ;;
    2) SCRIPT="02-build.sh" ;;
    3) SCRIPT="03-env.sh" ;;
    4) SCRIPT="04-infra.sh" ;;
    5) SCRIPT="05-seed.sh" ;;
    6) SCRIPT="06-start.sh" ;;
    *) err "Invalid step '$STEP' — must be 1-6" ;;
  esac
  log "Running step $STEP: $SCRIPT"
  DOCKER_ARGS+=("-it" "$IMAGE" "bash" "$SCRIPTS_MOUNT/$SCRIPT")

elif [ "$SKIP_BUILD" = true ]; then
  log "Running setup.sh with build step disabled..."
  # Temporarily override 02-build.sh with a no-op in the container
  DOCKER_ARGS+=(
    "-it" "$IMAGE" "bash" "-c"
    "echo '#!/bin/bash; echo \"[build] Skipped (--skip-build)\"; exit 0' > /tmp/02-build.sh && \
     chmod +x /tmp/02-build.sh && \
     ln -sf /tmp/02-build.sh /workspaces/dev/.devcontainer/scripts/02-build.sh; \
     bash /workspaces/dev/.devcontainer/setup.sh"
  )

else
  log "Running full setup.sh..."
  DOCKER_ARGS+=("-it" "$IMAGE" "bash" "/workspaces/dev/.devcontainer/setup.sh")
fi

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}  ═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  xshopai — Local Codespace Test${NC}"
echo -e "${CYAN}  Workspace root: $WORKSPACE_ROOT${NC}"
echo -e "${CYAN}  Network:        $NETWORK${NC}"
echo -e "${CYAN}  ═══════════════════════════════════════════════════${NC}"
echo ""

docker "${DOCKER_ARGS[@]}"
