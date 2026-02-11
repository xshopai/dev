#!/bin/bash

# =============================================================================
# xshopai Build Services Script
# =============================================================================
# This script builds individual services or all services with comprehensive
# support for cleaning, testing, and multiple technology stacks.

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service definitions with folder paths (format: "type:folder")
declare -A SERVICES=(
    ["auth-service"]="node:."
    ["user-service"]="node:."
    ["admin-service"]="node:."
    ["audit-service"]="node:."
    ["notification-service"]="typescript:."
    ["review-service"]="node:."
    ["chat-service"]="typescript:."
    ["web-bff"]="typescript:."
    ["product-service"]="python:."
    ["inventory-service"]="python:."
    ["order-service"]="dotnet:."
    ["payment-service"]="dotnet:."
    ["order-processor-service"]="java:."
    ["cart-service"]="java:."
    ["admin-ui"]="react:."
    ["customer-ui"]="react:."
)

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Get service path
get_service_path() {
    local service_name=$1
    local service_info="${SERVICES[$service_name]}"
    local folder="${service_info#*:}"
    echo "$WORKSPACE_ROOT/$folder/$service_name"
}

# Get service type
get_service_type() {
    local service_name=$1
    local service_info="${SERVICES[$service_name]}"
    echo "${service_info%%:*}"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [options] [service-names...]

Build xshopai microservices with comprehensive options

Options:
  --all                    Build all services
  --clean                  Clean dependencies before building
  --test                   Run tests after building
  --sequential             Build services sequentially (default: parallel for --all)
  --clean-only             Only perform cleanup, don't build
  --docker                 Also clean Docker build cache (with --clean-only)
  --logs                   Also clean log files (with --clean-only)
  --dry-run                Show what would be cleaned/built without doing it
  --help, -h               Show this help message

Arguments:
  service-names            Names of specific services to build (space separated)

Examples:
  $0 user-service                           # Build single service
  $0 user-service auth-service              # Build multiple services
  $0 --all                                  # Build all services (parallel)
  $0 --all --sequential                     # Build all services (sequential)
  $0 --all --clean --test                   # Clean, build, and test all services
  $0 user-service --clean                   # Clean build single service
  $0 --clean-only                           # Clean all build artifacts
  $0 --clean-only --service=user-service    # Clean specific service only
  $0 --clean-only --docker --logs           # Clean everything including Docker/logs

Available Services:
EOF
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        local service_type="${service_info%%:*}"
        local folder="${service_info#*:}"
        echo "  - $service ($service_type in $folder/)"
    done | sort
    echo ""
    echo "Technology Support:"
    echo "  - Node.js (npm install, npm test)"
    echo "  - TypeScript (npm install, npm run build, npm test)"
    echo "  - Python (pip install, syntax check, pytest)"
    echo "  - .NET (dotnet restore, dotnet build, dotnet test)"
    echo "  - Java (mvn clean compile, mvn test)"
    echo "  - Go (go mod download, go build, go test)"
    echo ""
}

# Function to display results table
display_results_table() {
    local temp_dir=$1
    
    if [[ ! -f "$temp_dir/build_results.txt" ]]; then
        return 0
    fi
    
    echo ""
    log_info "📊 Detailed Build Results:"
    echo ""
    
    # Table header
    printf "%-25s %-10s %-12s %-30s\n" "SERVICE" "STATUS" "BUILD TIME" "DETAILS"
    printf "%-25s %-10s %-12s %-30s\n" "=========================" "==========" "============" "=============================="
    
    # Sort services by name and display results
    sort "$temp_dir/build_results.txt" | while IFS='|' read -r service status time details; do
        if [[ "$status" == "SUCCESS" ]]; then
            printf "%-25s ${GREEN}%-10s${NC} %-12s %-30s\n" "$service" "$status" "$time" "$details"
        else
            printf "%-25s ${RED}%-10s${NC} %-12s %-30s\n" "$service" "$status" "$time" "$details"
        fi
    done
    
    echo ""
}

# Clean build artifacts for a service
clean_service_artifacts() {
    local service_name=$1
    local service_type=$2
    local dry_run=${3:-false}
    local clean_docker=${4:-false}
    local clean_logs=${5:-false}
    
    if [[ "$dry_run" == true ]]; then
        log_info "[DRY RUN] Would clean artifacts for $service_name ($service_type)"
    else
        log_info "🧹 Cleaning artifacts for $service_name ($service_type)"
    fi
    
    local service_path=$(get_service_path "$service_name")
    
    if [[ ! -d "$service_path" ]]; then
        log_warn "Directory $service_path not found, skipping"
        return 0
    fi
    
    # Save current directory
    local original_dir="$(pwd)"
    cd "$service_path"
    
    case $service_type in
        "node" | "typescript")
            if [[ "$dry_run" == true ]]; then
                [[ -d "node_modules" ]] && log_debug "[DRY RUN] Would remove node_modules/"
                [[ -f "package-lock.json" ]] && log_debug "[DRY RUN] Would remove package-lock.json"
                [[ -d "dist" ]] && log_debug "[DRY RUN] Would remove dist/"
                [[ -d "build" ]] && log_debug "[DRY RUN] Would remove build/"
                [[ -d "coverage" ]] && log_debug "[DRY RUN] Would remove coverage/"
                [[ -d ".nyc_output" ]] && log_debug "[DRY RUN] Would remove .nyc_output/"
            else
                [[ -d "node_modules" ]] && rm -rf node_modules && log_debug "Removed node_modules/"
                [[ -f "package-lock.json" ]] && rm -f package-lock.json && log_debug "Removed package-lock.json"
                [[ -d "dist" ]] && rm -rf dist && log_debug "Removed dist/"
                [[ -d "build" ]] && rm -rf build && log_debug "Removed build/"
                [[ -d "coverage" ]] && rm -rf coverage && log_debug "Removed coverage/"
                [[ -d ".nyc_output" ]] && rm -rf .nyc_output && log_debug "Removed .nyc_output/"
            fi
            ;;
        "python")
            if [[ "$dry_run" == true ]]; then
                log_debug "[DRY RUN] Would remove Python cache files"
                [[ -d ".pytest_cache" ]] && log_debug "[DRY RUN] Would remove .pytest_cache/"
                [[ -f ".coverage" ]] && log_debug "[DRY RUN] Would remove .coverage"
                [[ -d "htmlcov" ]] && log_debug "[DRY RUN] Would remove htmlcov/"
            else
                find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
                find . -name "*.pyc" -delete 2>/dev/null || true
                find . -name "*.pyo" -delete 2>/dev/null || true
                [[ -d ".pytest_cache" ]] && rm -rf .pytest_cache && log_debug "Removed .pytest_cache/"
                [[ -f ".coverage" ]] && rm -f .coverage && log_debug "Removed .coverage"
                [[ -d "htmlcov" ]] && rm -rf htmlcov && log_debug "Removed htmlcov/"
                log_debug "Cleaned Python cache files"
            fi
            ;;
        "dotnet")
            if [[ "$dry_run" == true ]]; then
                if [[ "$service_name" == "order-service" ]]; then
                    [[ -d "OrderService.Api/bin" ]] && log_debug "[DRY RUN] Would remove OrderService.Api/bin/"
                    [[ -d "OrderService.Api/obj" ]] && log_debug "[DRY RUN] Would remove OrderService.Api/obj/"
                    [[ -d "OrderService.Core/bin" ]] && log_debug "[DRY RUN] Would remove OrderService.Core/bin/"
                    [[ -d "OrderService.Core/obj" ]] && log_debug "[DRY RUN] Would remove OrderService.Core/obj/"
                    [[ -d "OrderService.Tests/bin" ]] && log_debug "[DRY RUN] Would remove OrderService.Tests/bin/"
                    [[ -d "OrderService.Tests/obj" ]] && log_debug "[DRY RUN] Would remove OrderService.Tests/obj/"
                elif [[ "$service_name" == "payment-service" ]]; then
                    [[ -d "PaymentService/bin" ]] && log_debug "[DRY RUN] Would remove PaymentService/bin/"
                    [[ -d "PaymentService/obj" ]] && log_debug "[DRY RUN] Would remove PaymentService/obj/"
                    [[ -d "PaymentService.Tests/bin" ]] && log_debug "[DRY RUN] Would remove PaymentService.Tests/bin/"
                    [[ -d "PaymentService.Tests/obj" ]] && log_debug "[DRY RUN] Would remove PaymentService.Tests/obj/"
                else
                    [[ -d "bin" ]] && log_debug "[DRY RUN] Would remove bin/"
                    [[ -d "obj" ]] && log_debug "[DRY RUN] Would remove obj/"
                fi
            else
                if [[ "$service_name" == "order-service" ]]; then
                    [[ -d "OrderService.Api/bin" ]] && rm -rf OrderService.Api/bin && log_debug "Removed OrderService.Api/bin/"
                    [[ -d "OrderService.Api/obj" ]] && rm -rf OrderService.Api/obj && log_debug "Removed OrderService.Api/obj/"
                    [[ -d "OrderService.Core/bin" ]] && rm -rf OrderService.Core/bin && log_debug "Removed OrderService.Core/bin/"
                    [[ -d "OrderService.Core/obj" ]] && rm -rf OrderService.Core/obj && log_debug "Removed OrderService.Core/obj/"
                    [[ -d "OrderService.Tests/bin" ]] && rm -rf OrderService.Tests/bin && log_debug "Removed OrderService.Tests/bin/"
                    [[ -d "OrderService.Tests/obj" ]] && rm -rf OrderService.Tests/obj && log_debug "Removed OrderService.Tests/obj/"
                    if command -v dotnet &> /dev/null; then
                        dotnet clean OrderService.sln &> /dev/null || true
                    fi
                elif [[ "$service_name" == "payment-service" ]]; then
                    [[ -d "PaymentService/bin" ]] && rm -rf PaymentService/bin && log_debug "Removed PaymentService/bin/"
                    [[ -d "PaymentService/obj" ]] && rm -rf PaymentService/obj && log_debug "Removed PaymentService/obj/"
                    [[ -d "PaymentService.Tests/bin" ]] && rm -rf PaymentService.Tests/bin && log_debug "Removed PaymentService.Tests/bin/"
                    [[ -d "PaymentService.Tests/obj" ]] && rm -rf PaymentService.Tests/obj && log_debug "Removed PaymentService.Tests/obj/"
                    if command -v dotnet &> /dev/null; then
                        cd PaymentService && dotnet clean &> /dev/null || true && cd ..
                        cd PaymentService.Tests && dotnet clean &> /dev/null || true && cd ..
                    fi
                else
                    [[ -d "bin" ]] && rm -rf bin && log_debug "Removed bin/"
                    [[ -d "obj" ]] && rm -rf obj && log_debug "Removed obj/"
                    if command -v dotnet &> /dev/null; then
                        dotnet clean &> /dev/null || true
                    fi
                fi
            fi
            ;;
        "java")
            if [[ "$dry_run" == true ]]; then
                [[ -d "target" ]] && log_debug "[DRY RUN] Would remove target/"
                [[ -d ".gradle" ]] && log_debug "[DRY RUN] Would remove .gradle/"
            else
                [[ -d "target" ]] && rm -rf target && log_debug "Removed target/"
                [[ -d ".gradle" ]] && rm -rf .gradle && log_debug "Removed .gradle/"
            fi
            ;;
        "go")
            if [[ "$dry_run" == true ]]; then
                [[ -d "bin" ]] && log_debug "[DRY RUN] Would remove bin/"
                log_debug "[DRY RUN] Would clean Go cache"
            else
                [[ -d "bin" ]] && rm -rf bin && log_debug "Removed bin/"
                if command -v go &> /dev/null; then
                    go clean -cache -modcache -testcache 2>/dev/null || true
                    log_debug "Cleaned Go cache"
                fi
            fi
            ;;
    esac
    
    # Clean logs if requested
    if [[ "$clean_logs" == true ]]; then
        if [[ "$dry_run" == true ]]; then
            [[ -d "logs" ]] && log_debug "[DRY RUN] Would clean logs/"
        else
            if [[ -d "logs" ]]; then
                find logs -name "*.log" -delete 2>/dev/null || true
                log_debug "Cleaned log files"
            fi
        fi
    fi
    
    # Return to original directory
    cd "$original_dir"
}

# Parse arguments
CLEAN=false
TEST=false
SEQUENTIAL=false
BUILD_ALL=false
CLEAN_ONLY=false
CLEAN_DOCKER=false
CLEAN_LOGS=false
DRY_RUN=false
SERVICES_TO_BUILD=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            BUILD_ALL=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --sequential)
            SEQUENTIAL=true
            shift
            ;;
        --clean-only)
            CLEAN_ONLY=true
            shift
            ;;
        --docker)
            CLEAN_DOCKER=true
            shift
            ;;
        --logs)
            CLEAN_LOGS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        --service=*)
            # Support --service=name format for clean-only compatibility
            service_name="${1#*=}"
            if [[ -n "${SERVICES[$service_name]:-}" ]]; then
                SERVICES_TO_BUILD+=("$service_name")
            else
                log_error "Unknown service: $service_name"
                exit 1
            fi
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            # Service names as positional arguments
            if [[ -n "${SERVICES[$1]:-}" ]]; then
                SERVICES_TO_BUILD+=("$1")
            else
                log_error "Unknown service: $1"
                log_info "Available services: ${!SERVICES[*]}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ "$BUILD_ALL" == false && ${#SERVICES_TO_BUILD[@]} -eq 0 && "$CLEAN_ONLY" == false ]]; then
    log_error "No services specified and --all not used"
    log_info "Use --all to build all services or specify service names"
    log_info "Use --clean-only to clean without building"
    show_usage
    exit 1
fi

if [[ "$BUILD_ALL" == true && ${#SERVICES_TO_BUILD[@]} -gt 0 ]]; then
    log_warn "--all flag used with specific services, building all services"
    SERVICES_TO_BUILD=()
fi

# Function to build a single service
build_service() {
    local service_name=$1
    local service_type=$2
    local temp_dir=${3:-""}
    local start_time=$(date +%s)
    
    log_info "🔨 Building $service_name ($service_type)..."
    
    local service_path=$(get_service_path "$service_name")
    
    if [[ ! -d "$service_path" ]]; then
        log_error "Directory $service_path not found"
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|Directory not found" >> "$temp_dir/build_results.txt"
        return 1
    fi
    
    # Clean if requested (but stay in script directory)
    if [[ "$CLEAN" == true ]]; then
        clean_service_artifacts "$service_name" "$service_type" "$DRY_RUN" false false
    fi
    
    # Ensure we're in the script directory before changing to service directory
    cd "$SCRIPT_DIR"
    
    # Now change to service directory for build operations
    cd "$service_path"
    local build_error=""
    
    if [[ "$DRY_RUN" == true ]]; then
        log_debug "[DRY RUN] Would build $service_name using $service_type build process"
        cd "$SCRIPT_DIR"
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        [[ -n "$temp_dir" ]] && echo "$service_name|SUCCESS|${duration}s|Dry run completed" >> "$temp_dir/build_results.txt"
        return 0
    fi
    
    case $service_type in
        "node")
            if [[ ! -f "package.json" ]]; then
                log_error "package.json not found"
                build_error="package.json not found"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            log_debug "Installing dependencies..."
            if ! npm install 2>&1; then
                log_error "npm install failed"
                build_error="npm install failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            # Node.js services (non-TypeScript) don't have build step
            log_debug "No build step required for Node.js service"
            
            if [[ "$TEST" == true ]]; then
                if npm run 2>&1 | grep -q "test"; then
                    log_debug "Running tests..."
                    if ! npm test 2>&1; then
                        log_error "npm test failed"
                        build_error="npm test failed"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    fi
                else
                    log_warn "No test script found, skipping tests"
                fi
            fi
            ;;
            
        "typescript")
            if [[ ! -f "package.json" ]]; then
                log_error "package.json not found"
                build_error="package.json not found"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            log_debug "Installing dependencies..."
            if ! npm install 2>&1; then
                log_error "npm install failed"
                build_error="npm install failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            log_debug "Building TypeScript..."
            if ! npm run build 2>&1; then
                log_error "npm run build failed"
                build_error="npm run build failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            if [[ "$TEST" == true ]]; then
                if npm run 2>&1 | grep -q "test"; then
                    log_debug "Running tests..."
                    if ! npm test 2>&1; then
                        log_error "npm test failed"
                        build_error="npm test failed"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    fi
                else
                    log_warn "No test script found, skipping tests"
                fi
            fi
            ;;
            
        "dotnet")
            # Special handling for order-service with solution file
            if [[ "$service_name" == "order-service" ]]; then
                if [[ ! -f "OrderService.sln" ]]; then
                    log_error "OrderService.sln not found"
                    build_error="OrderService.sln not found"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
                
                log_debug "Restoring packages..."
                if ! dotnet restore OrderService.sln 2>&1; then
                    log_error "dotnet restore failed"
                    build_error="dotnet restore failed"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
                
                log_debug "Building solution..."
                if ! dotnet build OrderService.sln --configuration Release --no-restore 2>&1; then
                    log_error "dotnet build failed"
                    build_error="dotnet build failed"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
                
                if [[ "$TEST" == true ]]; then
                    log_debug "Running tests..."
                    if ! dotnet test OrderService.sln --no-build --configuration Release 2>&1; then
                        log_error "dotnet test failed"
                        build_error="dotnet test failed"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    fi
                fi
                
            elif [[ "$service_name" == "payment-service" ]]; then
                cd "PaymentService"
                
                log_debug "Restoring packages..."
                if ! dotnet restore 2>&1; then
                    log_error "dotnet restore failed"
                    build_error="dotnet restore failed"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
                
                log_debug "Building..."
                if ! dotnet build --configuration Release --no-restore 2>&1; then
                    log_error "dotnet build failed"
                    build_error="dotnet build failed"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
                
                if [[ "$TEST" == true ]]; then
                    log_debug "Running tests..."
                    cd "../PaymentService.Tests"
                    if ! dotnet build --configuration Release 2>&1; then
                        log_error "dotnet test build failed"
                        build_error="dotnet test build failed"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    fi
                    if ! dotnet test --no-build --configuration Release 2>&1; then
                        log_error "dotnet test failed"
                        build_error="dotnet test failed"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    fi
                fi
            else
                log_error "Unknown .NET service structure"
                build_error="Unknown .NET service structure"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            ;;
            
        "java")
            if [[ ! -f "pom.xml" ]]; then
                log_error "pom.xml not found"
                build_error="pom.xml not found"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            local maven_cmd="mvn"
            if [[ -f "/c/ProgramData/chocolatey/lib/maven/apache-maven-3.9.11/bin/mvn" ]]; then
                maven_cmd="/c/ProgramData/chocolatey/lib/maven/apache-maven-3.9.11/bin/mvn"
            fi
            
            log_debug "Compiling..."
            if ! "$maven_cmd" clean compile 2>&1; then
                log_error "maven compile failed"
                build_error="maven compile failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            if [[ "$TEST" == true ]]; then
                log_debug "Running tests..."
                if ! "$maven_cmd" test 2>&1; then
                    log_error "maven test failed"
                    build_error="maven test failed"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
            fi
            ;;
            
        "python")
            if [[ -f "requirements.txt" ]]; then
                log_debug "Installing dependencies..."
                if ! pip install -r requirements.txt 2>&1; then
                    log_error "pip install failed"
                    build_error="pip install failed"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
            fi
            
            # Python syntax check
            log_debug "Checking Python syntax..."
            local entry_points=("run.py" "app.py" "main.py" "src/main.py")
            local syntax_checked=false
            
            for entry_point in "${entry_points[@]}"; do
                if [[ -f "$entry_point" ]]; then
                    python -m py_compile "$entry_point" || {
                        log_error "Syntax error in $entry_point"
                        build_error="Syntax error in $entry_point"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    }
                    syntax_checked=true
                    break
                fi
            done
            
            if [[ "$syntax_checked" == false ]]; then
                log_debug "No standard entry point found, checking all Python files..."
                local python_files=$(find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" -not -path "./__pycache__/*" | head -5)
                if [[ -n "$python_files" ]]; then
                    while IFS= read -r file; do
                        python -m py_compile "$file" || {
                            log_error "Syntax error in $file"
                            build_error="Syntax error in $file"
                            cd "$SCRIPT_DIR"
                            local end_time=$(date +%s)
                            local duration=$((end_time - start_time))
                            [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                            return 1
                        }
                    done <<< "$python_files"
                    log_debug "Python syntax check passed"
                fi
            fi
            
            if [[ "$TEST" == true ]]; then
                if [[ -f "run_tests.py" ]]; then
                    log_debug "Running tests via run_tests.py..."
                    python run_tests.py || {
                        log_error "Custom test runner failed"
                        build_error="Custom test runner failed"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    }
                elif [[ -f "pytest.ini" || -d "tests" || -d "test" ]]; then
                    log_debug "Running tests with pytest..."
                    python -m pytest -v || {
                        log_error "pytest failed"
                        build_error="pytest failed"
                        cd "$SCRIPT_DIR"
                        local end_time=$(date +%s)
                        local duration=$((end_time - start_time))
                        [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                        return 1
                    }
                else
                    log_warn "No tests found, skipping test execution"
                fi
            fi
            ;;
            
        "react")
            if [[ ! -f "package.json" ]]; then
                log_error "package.json not found"
                build_error="package.json not found"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            log_debug "Installing dependencies..."
            if ! npm install 2>&1; then
                log_error "npm install failed"
                build_error="npm install failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            log_debug "Building React app..."
            if ! npm run build 2>&1; then
                log_error "npm run build failed"
                build_error="npm run build failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            if [[ "$TEST" == true ]]; then
                if npm run 2>&1 | grep -q "test"; then
                    log_debug "Running tests..."
                    if ! npm test -- --watchAll=false 2>&1; then
                        log_warn "npm test failed or no tests configured"
                    fi
                else
                    log_warn "No test script found, skipping tests"
                fi
            fi
            ;;
            
        "go")
            if [[ ! -f "go.mod" ]]; then
                log_error "go.mod not found"
                build_error="go.mod not found"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            log_debug "Downloading dependencies..."
            if ! go mod download 2>&1; then
                log_error "go mod download failed"
                build_error="go mod download failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            log_debug "Building..."
            # Determine output binary name based on service
            local binary_name="$service_name"
            
            if ! go build -o "bin/$binary_name" ./cmd/server 2>&1; then
                log_error "go build failed"
                build_error="go build failed"
                cd "$SCRIPT_DIR"
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                return 1
            fi
            
            if [[ "$TEST" == true ]]; then
                log_debug "Running tests..."
                if ! go test ./... -v 2>&1; then
                    log_error "go test failed"
                    build_error="go test failed"
                    cd "$SCRIPT_DIR"
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
                    return 1
                fi
            fi
            ;;
            
        *)
            log_error "Unknown service type: $service_type"
            build_error="Unknown service type: $service_type"
            cd "$SCRIPT_DIR"
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            [[ -n "$temp_dir" ]] && echo "$service_name|FAILED|${duration}s|$build_error" >> "$temp_dir/build_results.txt"
            return 1
            ;;
    esac
    
    cd "$SCRIPT_DIR"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "✅ $service_name completed successfully (${duration}s)"
    
    # Record success result for table display
    [[ -n "$temp_dir" ]] && echo "$service_name|SUCCESS|${duration}s|Build completed successfully" >> "$temp_dir/build_results.txt"
    return 0
}

# Main execution logic
main() {
    local start_time=$(date +%s)
    
    # Handle clean-only mode
    if [[ "$CLEAN_ONLY" == true ]]; then
        log_info "🧹 Clean-only mode activated"
        
        if [[ ${#SERVICES_TO_BUILD[@]} -gt 0 ]]; then
            # Clean specific services
            for service_name in "${SERVICES_TO_BUILD[@]}"; do
                local service_type=$(get_service_type "$service_name")
                clean_service_artifacts "$service_name" "$service_type" "$DRY_RUN" "$CLEAN_DOCKER" "$CLEAN_LOGS"
            done
        else
            # Clean all services
            for service_name in "${!SERVICES[@]}"; do
                local service_type=$(get_service_type "$service_name")
                clean_service_artifacts "$service_name" "$service_type" "$DRY_RUN" "$CLEAN_DOCKER" "$CLEAN_LOGS"
            done
        fi
        
        # Clean Docker build cache if requested
        if [[ "$CLEAN_DOCKER" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_debug "[DRY RUN] Would clean Docker build cache"
            else
                if command -v docker &> /dev/null; then
                    log_info "🧹 Cleaning Docker build cache..."
                    docker builder prune -f &> /dev/null || log_warn "Docker builder prune failed"
                else
                    log_warn "Docker not available, skipping Docker cache cleanup"
                fi
            fi
        fi
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_info "✅ Cleanup completed (${duration}s)"
        return 0
    fi
    
    # Determine services to build
    local services_list=()
    if [[ "$BUILD_ALL" == true ]]; then
        for service in "${!SERVICES[@]}"; do
            services_list+=("$service")
        done
        log_info "🚀 Building all ${#services_list[@]} services"
    else
        services_list=("${SERVICES_TO_BUILD[@]}")
        log_info "🚀 Building ${#services_list[@]} service(s): ${services_list[*]}"
    fi
    
    log_debug "Options: Clean=$CLEAN, Test=$TEST, Sequential=$SEQUENTIAL, DryRun=$DRY_RUN"
    echo ""
    
    # Build services
    local success_count=0
    local failed_services=()
    
    if [[ "$BUILD_ALL" == true && "$SEQUENTIAL" == false ]]; then
        log_info "⚡ Running builds in parallel..."
        
        # Parallel execution for --all
        local pids=()
        local temp_dir=$(mktemp -d)
        trap "rm -rf $temp_dir" EXIT
        
        for service in "${services_list[@]}"; do
            (
                local service_type=$(get_service_type "$service")
                if build_service "$service" "$service_type" "$temp_dir"; then
                    echo "$service:SUCCESS" >> "$temp_dir/results.txt"
                else
                    echo "$service:FAILED" >> "$temp_dir/results.txt"
                fi
            ) &
            pids+=($!)
        done
        
        # Wait for all builds
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        # Display detailed results table
        display_results_table "$temp_dir"
        
        # Collect results
        if [[ -f "$temp_dir/results.txt" ]]; then
            while IFS=':' read -r service status; do
                if [[ "$status" == "SUCCESS" ]]; then
                    success_count=$((success_count + 1))
                else
                    failed_services+=("$service")
                fi
            done < "$temp_dir/results.txt"
        fi
        
    else
        log_info "🔄 Running builds sequentially..."
        
        # Sequential execution - create temp dir for table display
        local temp_dir=$(mktemp -d)
        trap "rm -rf $temp_dir" EXIT
        
        for service in "${services_list[@]}"; do
            log_info "📍 Building $service..."
            local service_type=$(get_service_type "$service")
            if build_service "$service" "$service_type" "$temp_dir"; then
                success_count=$((success_count + 1))
            else
                failed_services+=("$service")
            fi
            echo ""
        done
        
        # Display detailed results table
        display_results_table "$temp_dir"
    fi
    
    # Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_info "📊 Build Summary:"
    log_info "✅ Successful: $success_count/${#services_list[@]}"
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_error "❌ Failed: ${failed_services[*]}"
    fi
    
    log_info "⏱️  Total Duration: ${duration}s"
    
    if [[ $success_count -eq ${#services_list[@]} ]]; then
        log_info "🎉 All builds completed successfully!"
        exit 0
    else
        log_error "💥 Some builds failed"
        exit 1
    fi
}


# Check Docker availability for Docker cleanup
if [[ "$CLEAN_DOCKER" == true ]]; then
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not available, ignoring --docker flag"
        CLEAN_DOCKER=false
    fi
fi

# Run main function
main
