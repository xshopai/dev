#!/bin/bash
# =============================================================================
# 00-prerequisites.sh — Verify all required tools are installed
# =============================================================================
# Checks for Docker, Node.js, Python, Java, .NET SDK, and Git.
# Exits 1 if any are missing.
# =============================================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
_ts() { date -u '+%H:%M:%S'; }
log()     { echo -e "${BLUE}[prereq $(_ts)]${NC} $1"; }
success() { echo -e "${GREEN}[prereq $(_ts)]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[prereq $(_ts)]${NC} ⚠ $1"; }
err()     { echo -e "${RED}[prereq $(_ts)]${NC} ✗ $1"; }

MISSING=()

# Docker
if command -v docker &>/dev/null; then
  success "Docker  $(docker --version 2>/dev/null | head -1)"
else
  err "Docker not found"
  MISSING+=("Docker — https://docs.docker.com/get-docker/")
fi

# Docker Compose (v2 plugin or standalone)
if docker compose version &>/dev/null 2>&1; then
  success "Docker Compose  $(docker compose version --short 2>/dev/null)"
elif command -v docker-compose &>/dev/null; then
  success "Docker Compose  $(docker-compose --version 2>/dev/null | head -1)"
else
  err "Docker Compose not found"
  MISSING+=("Docker Compose — included with Docker Desktop, or install separately")
fi

# Node.js
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>/dev/null)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
  if [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null; then
    success "Node.js  $NODE_VER"
  else
    warn "Node.js $NODE_VER found but version 18+ is required"
    MISSING+=("Node.js 18+ — https://nodejs.org/")
  fi
else
  err "Node.js not found"
  MISSING+=("Node.js 18+ — https://nodejs.org/")
fi

# npm (comes with Node but verify)
if command -v npm &>/dev/null; then
  success "npm  $(npm --version 2>/dev/null)"
fi

# Python
PYTHON_CMD=""
if command -v python3 &>/dev/null; then
  PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
  PYTHON_CMD="python"
fi

if [ -n "$PYTHON_CMD" ]; then
  PY_VER=$($PYTHON_CMD --version 2>/dev/null)
  success "Python  $PY_VER"
else
  err "Python not found"
  MISSING+=("Python 3.12+ — https://www.python.org/downloads/")
fi

# Java
if command -v java &>/dev/null; then
  JAVA_VER=$(java -version 2>&1 | head -1)
  success "Java  $JAVA_VER"
else
  err "Java not found"
  MISSING+=("Java 17+ — https://adoptium.net/")
fi

# Maven (for order-processor-service)
if command -v mvn &>/dev/null; then
  success "Maven  $(mvn --version 2>/dev/null | head -1)"
else
  warn "Maven not found — needed for order-processor-service"
  MISSING+=("Maven — https://maven.apache.org/download.cgi")
fi

# .NET SDK
if command -v dotnet &>/dev/null; then
  success ".NET SDK  $(dotnet --version 2>/dev/null)"
else
  err ".NET SDK not found"
  MISSING+=(".NET 8 SDK — https://dotnet.microsoft.com/download")
fi

# Git
if command -v git &>/dev/null; then
  success "Git  $(git --version 2>/dev/null)"
else
  err "Git not found"
  MISSING+=("Git — https://git-scm.com/")
fi

# Summary
echo ""
if [ ${#MISSING[@]} -gt 0 ]; then
  err "Missing ${#MISSING[@]} prerequisite(s):"
  for item in "${MISSING[@]}"; do
    echo -e "  ${RED}•${NC} $item"
  done
  echo ""
  err "Install the missing tools and re-run this script."
  exit 1
else
  success "All prerequisites met!"
fi
