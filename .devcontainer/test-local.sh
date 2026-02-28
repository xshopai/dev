#!/bin/bash
# =============================================================================
# test-local.sh — Simulate GitHub Codespace creation locally
# =============================================================================
# One command — fully automated. No manual steps needed.
#
# What it does (mirrors exactly what Codespaces does):
#   1. Starts the infra Docker Compose stack (Mongo, Redis, RabbitMQ, etc.)
#   2. Runs setup.sh inside the real devcontainer image on the same network
#   3. Repos persist in a named Docker volume (no re-cloning on repeat runs)
#   4. Reuses the same dependency cache volumes as the real devcontainer
#   5. The dev/ repo is always bind-mounted live — script changes take effect
#      immediately without needing to rebuild or reset anything
#
# Usage:
#   bash .devcontainer/test-local.sh            # run (incremental — fast after first)
#   bash .devcontainer/test-local.sh --reset    # wipe repo volume, start truly fresh
#   bash .devcontainer/test-local.sh --step N   # run only one sub-script (1-6)
#   bash .devcontainer/test-local.sh --shell    # interactive shell (no setup.sh)
#   bash .devcontainer/test-local.sh --stop     # stop infra and cleanup
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(dirname "$DEVCONTAINER_DIR")"           # .../xshopai/dev
XSHOPAI_ROOT="$(dirname "$DEV_DIR")"              # .../xshopai

IMAGE="mcr.microsoft.com/devcontainers/universal:2"

# Docker volume names (mirrors docker-compose.devcontainer.yml)
VOL_WORKSPACES="xshopai-test-workspaces"          # persists all cloned repos
VOL_NPM="xshopai-devcontainer-npm"
VOL_M2="xshopai-devcontainer-m2"
VOL_PIP="xshopai-devcontainer-pip"
VOL_NUGET="xshopai-devcontainer-nuget"

NETWORK="xshopai-dev-network"

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
RESET=false
STOP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)    RESET=true; shift ;;
    --stop)     STOP=true; shift ;;
    --shell)    SHELL_MODE=true; shift ;;
    --step)     STEP="$2"; shift 2 ;;
    --step=*)   STEP="${1#*=}"; shift ;;
    -h|--help)
      echo ""
      echo "Usage: bash .devcontainer/test-local.sh [option]"
      echo ""
      echo "  (no args)    Simulate Codespace — start infra, run full setup.sh"
      echo "               (repos cached in Docker volume, fast on repeat runs)"
      echo "  --reset      Wipe the repo volume first — truly fresh Codespace sim"
      echo "  --step N     Run only one sub-script (1=clone 2=build 3=env"
      echo "               4=infra 5=seed 6=start)"
      echo "  --shell      Open interactive bash inside the devcontainer image"
      echo "  --stop       Stop infra containers and remove test volume"
      echo ""
      exit 0
      ;;
    *) err "Unknown argument: $1 — use --help" ;;
  esac
done

# ---------------------------------------------------------------------------
# --stop: tear down infra + wipe volume
# ---------------------------------------------------------------------------
if [ "$STOP" = true ]; then
  log "Stopping infra stack..."
  (cd "$DEV_DIR" && docker compose down) || true
  log "Removing workspaces volume ($VOL_WORKSPACES)..."
  docker volume rm "$VOL_WORKSPACES" 2>/dev/null && success "Volume removed" || warn "Volume not found"
  success "Stopped"
  exit 0
fi

# ---------------------------------------------------------------------------
# --reset: wipe repo volume (infra kept running)
# ---------------------------------------------------------------------------
if [ "$RESET" = true ]; then
  log "Wiping repo volume for fresh Codespace simulation..."
  docker volume rm "$VOL_WORKSPACES" 2>/dev/null && success "Volume wiped — next run clones fresh" || warn "Volume not found (already clean)"
  log "Re-run without --reset to start fresh"
  exit 0
fi

# ===========================================================================
# STEP 1 — Start infra stack (idempotent — already-running containers skip)
# ===========================================================================
echo ""
echo -e "${CYAN}  ══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  xshopai — Local Codespace Simulation${NC}"
echo -e "${CYAN}  ══════════════════════════════════════════════════════${NC}"
echo ""

log "Starting infra stack (docker compose up -d)..."
(cd "$DEV_DIR" && docker compose up -d)
success "Infra stack started"

# ===========================================================================
# STEP 2 — Ensure workspaces volume exists & dev/ is seeded into it
# ===========================================================================
# The volume holds all cloned repos at /workspaces/* (persists between runs).
# The dev repo inside the volume is a snapshot — we overlay the live bind-mount
# on top so script changes are always picked up without resetting anything.
log "Ensuring workspaces volume exists ($VOL_WORKSPACES)..."
docker volume inspect "$VOL_WORKSPACES" > /dev/null 2>&1 || {
  docker volume create "$VOL_WORKSPACES" > /dev/null
  success "Created volume $VOL_WORKSPACES"
}

# Seed dev/ into the volume if it's not already there.
# We detect this by checking for the .git directory via a tiny alpine container.
log "Checking dev repo in volume..."
DEV_IN_VOLUME=$(MSYS_NO_PATHCONV=1 docker run --rm \
  -v "${VOL_WORKSPACES}:/workspaces" \
  alpine sh -c '[ -d /workspaces/dev/.git ] && echo "yes" || echo "no"')

if [ "$DEV_IN_VOLUME" = "no" ]; then
  log "Copying dev repo into workspaces volume..."
  # Use alpine + tar to copy the host dev directory into the volume
  tar -C "$XSHOPAI_ROOT" -cf - dev | MSYS_NO_PATHCONV=1 docker run --rm -i \
    -v "${VOL_WORKSPACES}:/workspaces" \
    alpine sh -c 'tar -C /workspaces -xf -'
  success "dev repo seeded into volume"
else
  success "dev repo already in volume"
fi

# ===========================================================================
# STEP 3 — Pull image if not cached
# ===========================================================================
log "Checking image: $IMAGE"
docker image inspect "$IMAGE" > /dev/null 2>&1 || {
  warn "Image not cached — pulling (first time only, ~2-3 min)..."
  docker pull "$IMAGE"
}
success "Image ready"

# ===========================================================================
# STEP 4 — Build docker run command
# ===========================================================================
# Mirrors docker-compose.devcontainer.yml exactly:
#   - workspaces volume at /workspaces
#   - dev/ bind-mounted OVER the volume so live edits are always active
#   - all 4 dependency cache volumes
#   - docker socket (Docker-outside-of-Docker)
#   - xshopai-dev-network (same network as infra containers)

CONTAINER_NAME="xshopai-dev-test"

DOCKER_RUN=(
  docker run --rm -it
  --name "$CONTAINER_NAME"
  --network "$NETWORK"
  # Repo volume — persists cloned repos between test runs
  -v "${VOL_WORKSPACES}:/workspaces"
  # Bind-mount dev/ OVER the volume copy so latest scripts are always live
  -v "${DEV_DIR}:/workspaces/dev"
  # Dependency caches (shared with real devcontainer)
  -v "${VOL_NPM}:/home/codespace/.npm"
  -v "${VOL_M2}:/home/codespace/.m2"
  -v "${VOL_PIP}:/home/codespace/.cache/pip"
  -v "${VOL_NUGET}:/home/codespace/.nuget/packages"
  # Docker socket (Docker-outside-of-Docker)
  # MSYS_NO_PATHCONV=1 at run time prevents Git Bash converting this to a Windows path
  -v "/var/run/docker.sock:/var/run/docker.sock"
  # Publish all service ports so they're reachable on the host
  -p 3000:3000   # customer-ui
  -p 3001:3001   # admin-ui
  -p 8001:8001   # product-service
  -p 8002:8002   # user-service
  -p 8003:8003   # admin-service
  -p 8004:8004   # auth-service
  -p 8005:8005   # inventory-service
  -p 8006:8006   # order-service
  -p 8007:8007   # order-processor-service
  -p 8008:8008   # audit-service
  -p 8009:8009   # payment-service
  -p 8010:8010   # notification-service
  -p 8011:8011   # review-service
  -p 8012:8012   # cart-service
  -p 8013:8013   # chat-service
  -p 8014:8014   # web-bff
  # Environment — same as devcontainer.json remoteEnv
  # Uses container_name (dev-*) so these work from outside the Compose project
  -e CODESPACES=true
  -e NODE_ENV=development
  -e SERVICE_INVOCATION_MODE=http
  -e RABBITMQ_HOST=dev-rabbitmq
  -e RABBITMQ_PORT=5672
  -e RABBITMQ_USER=admin
  -e RABBITMQ_PASSWORD=admin123
  -e REDIS_HOST=dev-redis
  -e REDIS_PORT=6379
  -e REDIS_PASSWORD=redis_dev_pass_123
  -e ZIPKIN_URL="http://dev-zipkin:9411"
  -e MAILPIT_SMTP_HOST=dev-mailpit
  -e MAILPIT_SMTP_PORT=1025
  -e JWT_ALGORITHM=HS256
  -e JWT_EXPIRATION=24h
  -e JWT_ISSUER=auth-service
  -e CORS_ALLOWED_ORIGINS="http://localhost:3000,http://localhost:3001"
)

# ===========================================================================
# STEP 5 — Decide what to run
# ===========================================================================
SCRIPTS_DIR="/workspaces/dev/.devcontainer/scripts"

if [ "$SHELL_MODE" = true ]; then
  log "Opening interactive shell in devcontainer..."
  log "  Repos:   /workspaces/"
  log "  Scripts: $SCRIPTS_DIR/"
  log "  Logs:    /workspaces/dev/logs/"
  DOCKER_RUN+=("$IMAGE" bash)

elif [ -n "$STEP" ]; then
  case "$STEP" in
    1) SCRIPT="01-clone.sh" ;;
    2) SCRIPT="02-build.sh" ;;
    3) SCRIPT="03-env.sh"   ;;
    4) SCRIPT="04-infra.sh" ;;
    5) SCRIPT="05-seed.sh"  ;;
    6) SCRIPT="06-start.sh" ;;
    *) err "Invalid step '$STEP' — must be 1-6" ;;
  esac
  log "Running step $STEP: $SCRIPT"
  DOCKER_RUN+=("$IMAGE" bash "$SCRIPTS_DIR/$SCRIPT")

else
  # Full setup.sh — exactly what postCreateCommand runs in a real Codespace.
  # After setup.sh finishes (services launched in background), block with
  # `tail -f /dev/null` so the container stays alive and published ports
  # remain reachable on the host.  Press Ctrl+C to stop everything.
  log "Running setup.sh (full Codespace simulation)..."
  log "Tips:"
  log "  • Tail logs in another terminal: docker exec <id> tail -f /workspaces/dev/logs/setup.log"
  log "  • Repos cached in volume '$VOL_WORKSPACES' — repeat runs skip clone step"
  log "  • Use --reset to wipe and start fresh, --step N to test one phase"
  log "  • Press Ctrl+C to stop the container and all services"
  DOCKER_RUN+=("$IMAGE" bash -c '
    bash /workspaces/dev/.devcontainer/setup.sh
    echo ""
    echo "================================================================"
    echo " [test-local] Services are running — ports published to host"
    echo "   customer-ui  → http://localhost:3000"
    echo "   admin-ui     → http://localhost:3001"
    echo "   web-bff      → http://localhost:8014"
    echo ""
    echo "   Press Ctrl+C to stop the container and all services"
    echo "================================================================"
    tail -f /dev/null
  ')
fi

# ===========================================================================
# Run — stop any stale container first (prevents "port already allocated")
# ===========================================================================
echo ""
if docker inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
  warn "Stopping stale container '$CONTAINER_NAME'..."
  docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
  success "Stale container removed"
fi
# MSYS_NO_PATHCONV=1 prevents Git Bash (MSYS2) from converting absolute paths
# like /workspaces/... and /var/run/... into Windows paths (C:/Program Files/Git/...)
MSYS_NO_PATHCONV=1 "${DOCKER_RUN[@]}"
