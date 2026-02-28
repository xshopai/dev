#!/bin/bash
# =============================================================================
# xshopai Codespace Setup Script — Orchestrator
# =============================================================================
# Runs once after the devcontainer is first created (postCreateCommand).
#
# Design principles:
#   - No top-level set -e: each step is fail-soft; failures are tracked and
#     reported in a summary table rather than aborting the whole run.
#   - Sub-scripts: each phase lives in .devcontainer/scripts/ and writes its
#     own log to /workspaces/dev/logs/<step>.log
#   - Parallel builds: 02-build.sh groups services by runtime and runs waves
#     in parallel, with per-service log files for easy debugging.
# =============================================================================

WORKSPACES_DIR="/workspaces"
SCRIPTS_DIR="$WORKSPACES_DIR/dev/.devcontainer/scripts"
LOG_DIR="$WORKSPACES_DIR/dev/logs"
mkdir -p "$LOG_DIR"

# Named-volume cache directories may be owned by root on first mount (Docker
# creates the mount-point directory as root if it doesn't exist in the image).
# Fix ownership up-front before any build step runs. sudo is always available
# in devcontainers/universal.
sudo chown -R codespace:codespace \
  /home/codespace/.nuget \
  /home/codespace/.npm \
  /home/codespace/.m2 \
  /home/codespace/.cache \
  2>/dev/null || true
mkdir -p \
  /home/codespace/.nuget/NuGet \
  /home/codespace/.nuget/packages \
  /home/codespace/.npm \
  /home/codespace/.m2 \
  /home/codespace/.cache/pip

LOG_FILE="$LOG_DIR/setup.log"
# Write directly to LOG_FILE from each function rather than via exec >/tee.
# Using exec > >(tee >(sed ...)) causes bash to hang after setup completes:
# background services started by dev.sh inherit the pipe write-end, so tee
# never sees EOF and bash waits forever. Direct >> in each function avoids
# any pipe that background processes could accidentally keep alive.
echo "=== setup.sh started at $(date -u '+%Y-%m-%d %H:%M:%S UTC') ===" > "$LOG_FILE"
_SETUP_START=$SECONDS

# Colors
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
RED='\033[0;31m';   CYAN='\033[0;36m';   NC='\033[0m'

_ts()     { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[setup $(_ts)]${NC} $1";    echo "[setup $(_ts)] $1"   >> "$LOG_FILE"; }
success() { echo -e "${GREEN}[setup $(_ts)]${NC} ✓ $1"; echo "[setup $(_ts)] ✓ $1" >> "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[setup $(_ts)]${NC} ⚠ $1"; echo "[setup $(_ts)] ⚠ $1" >> "$LOG_FILE"; }
err()     { echo -e "${RED}[setup $(_ts)]${NC} ✗ $1";  echo "[setup $(_ts)] ✗ $1"  >> "$LOG_FILE"; }

# Fix execute permissions (Windows checkouts strip +x)
find "$WORKSPACES_DIR/dev" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   xshopai Platform — Codespace Setup     ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# Step runner — fail-soft: records failures without aborting
# =============================================================================
declare -A STEP_STATUS   # STEP_STATUS[name]="ok"|"failed"|"warn"
declare -A STEP_TIMES    # STEP_TIMES[name]=seconds

run_step() {
  local name="$1"
  local script="$2"
  shift 2
  local t=$SECONDS

  if [ ! -f "$script" ]; then
    warn "Skipping $name — $script not found"
    STEP_STATUS["$name"]="warn"
    STEP_TIMES["$name"]=0
    return
  fi

  log "▶ $name"
  chmod +x "$script" 2>/dev/null || true

  # Pipe step output to its own log file AND the terminal.
  # Plain tee only — no nested >(sed ...) process substitution.
  # Nested process substitution causes setup.sh to hang: background services
  # started by dev.sh inherit the pipe's write-end, so tee never sees EOF.
  # ANSI codes in step log files are acceptable (VS Code renders them).
  local step_log="$LOG_DIR/$(echo "$name" | tr ' /\\' '---' | tr '[:upper:]' '[:lower:]' | tr '.' '-').log"
  bash "$script" "$@" 2>&1 | tee "$step_log"
  local rc=${PIPESTATUS[0]}
  if [ $rc -eq 0 ]; then
    STEP_STATUS["$name"]="ok"
    success "$name  ($(( SECONDS - t ))s)"
  else
    STEP_STATUS["$name"]="failed"
    err "$name failed after $(( SECONDS - t ))s — see $step_log"
  fi
  STEP_TIMES["$name"]=$(( SECONDS - t ))
}

# =============================================================================
# Steps — each is independent; a failure is logged but does not stop the rest
# =============================================================================
STEPS=(
  "1. Clone repositories"
  "2. Build services"
  "3. Seed config / .env"
  "4. Check infrastructure"
  "5. Seed databases"
  "6. Start services"
)

run_step "1. Clone repositories"   "$SCRIPTS_DIR/01-clone.sh"
run_step "2. Build services"        "$SCRIPTS_DIR/02-build.sh"
run_step "3. Seed config / .env"    "$SCRIPTS_DIR/03-env.sh"
run_step "4. Check infrastructure"  "$SCRIPTS_DIR/04-infra.sh"
run_step "5. Seed databases"        "$SCRIPTS_DIR/05-seed.sh"
run_step "6. Start services"        "$SCRIPTS_DIR/06-start.sh"

# =============================================================================
# Summary
# =============================================================================
TOTAL=$(( SECONDS - _SETUP_START ))
PASS=0; FAIL=0; WARN=0

echo ""
echo -e "${CYAN}  ═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Setup complete in ${TOTAL}s${NC}"
echo -e "${CYAN}  ═══════════════════════════════════════════════════${NC}"

for step in "${STEPS[@]}"; do
  status="${STEP_STATUS["$step"]:-unknown}"
  t="${STEP_TIMES["$step"]:-?}s"
  case "$status" in
    ok)      echo -e "  ${GREEN}✓${NC} $step  ($t)"; (( PASS++ )) || true ;;
    failed)  echo -e "  ${RED}✗${NC} $step  ($t)"; (( FAIL++ )) || true ;;
    warn)    echo -e "  ${YELLOW}⚠${NC} $step  (skipped)"; (( WARN++ )) || true ;;
    *)       echo    "  ? $step" ;;
  esac
done

echo ""
if [ $FAIL -gt 0 ]; then
  echo -e "${YELLOW}  ⚠ $FAIL step(s) had errors — check logs in $LOG_DIR/${NC}"
else
  echo -e "${GREEN}  All steps passed!${NC}"
fi
echo -e "  Log file: $LOG_FILE"
echo -e "${CYAN}  ═══════════════════════════════════════════════════${NC}"
echo ""

# Open the multi-root workspace (fallback if workspaceFile in devcontainer.json
# did not trigger — harmless if it already opened)
code -r /workspaces/dev/xshopai.code-workspace 2>/dev/null || true

echo "=== setup.sh completed in ${TOTAL}s ===" | tee -a "$LOG_FILE"
