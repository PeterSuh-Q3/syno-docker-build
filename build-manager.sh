#!/usr/bin/env bash

# Synology Docker Build - Unified Build Manager
# Performance optimized build system with monitoring and caching

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_MANAGER="${SCRIPT_DIR}/scripts/cache-manager.sh"
PERFORMANCE_MONITOR="${SCRIPT_DIR}/scripts/performance-monitor.sh"
BUILD_PARALLEL="${SCRIPT_DIR}/build-parallel.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

###############################################################################
function print_banner() {
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                🚀 Synology Docker Build Manager               ║
║                     Performance Optimized                    ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

###############################################################################
function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

###############################################################################
function check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check required tools
    for cmd in docker curl tar bc; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing_deps+=($cmd)
        fi
    done
    
    # Check optional but recommended tools  
    for cmd in docker buildx iostat; do
        if ! command -v $cmd >/dev/null 2>&1; then
            log_warn "Optional tool missing: $cmd (recommended for better performance)"
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    log_info "✅ All dependencies satisfied"
}

###############################################################################
function prepare_environment() {
    log_info "Preparing build environment..."
    
    # Create necessary directories
    mkdir -p cache logs/performance scripts
    
    # Make scripts executable
    chmod +x "${CACHE_MANAGER}" "${PERFORMANCE_MONITOR}" "${BUILD_PARALLEL}" 2>/dev/null || true
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Enable BuildKit if available
    if docker buildx version >/dev/null 2>&1; then
        export DOCKER_BUILDKIT=1
        log_info "✅ Docker BuildKit enabled"
    fi
    
    log_info "✅ Environment prepared"
}

###############################################################################
function show_system_info() {
    log_info "System Information:"
    echo "   CPU Cores: $(nproc)"
    echo "   Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "   Disk Available: $(df -h . | tail -1 | awk '{print $4}')"
    echo "   Docker: $(docker --version | cut -d' ' -f3 | sed 's/,//')"
    
    if [ -x "${CACHE_MANAGER}" ]; then
        echo ""
        ${CACHE_MANAGER} status | head -10
    fi
}

###############################################################################
function quick_build() {
    log_info "🚀 Starting quick build (parallel optimized)"
    
    prepare_environment
    
    # Start performance monitoring
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        ${PERFORMANCE_MONITOR} start "quick-build"
    fi
    
    # Run optimized cache management
    if [ -x "${CACHE_MANAGER}" ]; then
        ${CACHE_MANAGER} validate
        ${CACHE_MANAGER} optimize
    fi
    
    # Execute build
    local build_result="success"
    if [ -x "${BUILD_PARALLEL}" ]; then
        ${BUILD_PARALLEL} all || build_result="failed"
    else
        log_warn "Falling back to original build script"
        ./build.sh || build_result="failed"
    fi
    
    # Stop monitoring
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        ${PERFORMANCE_MONITOR} stop "$build_result"
    fi
    
    if [ "$build_result" = "success" ]; then
        log_info "🎉 Build completed successfully!"
        return 0
    else
        log_error "❌ Build failed"
        return 1
    fi
}

###############################################################################
function platform_build() {
    local platform="$1"
    
    if [ -z "$platform" ]; then
        log_error "Platform not specified"
        show_help
        exit 1
    fi
    
    log_info "🔨 Building for platform: $platform"
    
    prepare_environment
    
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        ${PERFORMANCE_MONITOR} start "platform-build-$platform"
    fi
    
    local build_result="success"
    if [ -x "${BUILD_PARALLEL}" ]; then
        ${BUILD_PARALLEL} build "$platform" || build_result="failed"
    else
        log_error "Platform-specific build requires build-parallel.sh"
        exit 1
    fi
    
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        ${PERFORMANCE_MONITOR} stop "$build_result"
    fi
    
    if [ "$build_result" = "success" ]; then
        log_info "🎉 Platform $platform built successfully!"
    else
        log_error "❌ Platform $platform build failed"
        exit 1
    fi
}

###############################################################################
function maintenance() {
    log_info "🧹 Running maintenance tasks..."
    
    if [ -x "${CACHE_MANAGER}" ]; then
        ${CACHE_MANAGER} validate
        ${CACHE_MANAGER} optimize
        ${CACHE_MANAGER} clean 30
    fi
    
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        ${PERFORMANCE_MONITOR} cleanup 7
    fi
    
    # Docker cleanup
    log_info "Cleaning Docker resources..."
    docker system prune -f >/dev/null 2>&1 || true
    docker image prune -f >/dev/null 2>&1 || true
    
    log_info "✅ Maintenance completed"
}

###############################################################################
function benchmark() {
    log_info "📊 Running performance benchmark..."
    
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        ${PERFORMANCE_MONITOR} benchmark
    else
        log_warn "Performance monitoring not available"
    fi
}

###############################################################################
function show_status() {
    print_banner
    show_system_info
    
    echo ""
    log_info "Build Tools Status:"
    
    if [ -x "${BUILD_PARALLEL}" ]; then
        echo "   ✅ Parallel build script available"
    else
        echo "   ❌ Parallel build script missing"
    fi
    
    if [ -x "${CACHE_MANAGER}" ]; then
        echo "   ✅ Cache manager available"
    else
        echo "   ❌ Cache manager missing"
    fi
    
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        echo "   ✅ Performance monitoring available"
    else
        echo "   ❌ Performance monitoring missing"
    fi
    
    # Check recent builds
    if [ -x "${PERFORMANCE_MONITOR}" ]; then
        echo ""
        ${PERFORMANCE_MONITOR} history | tail -5
    fi
}

###############################################################################
function show_help() {
    print_banner
    cat << EOF
🛠️  Unified Build Manager for Synology Docker Compiler 7.3

USAGE:
    $0 [command] [options]

COMMANDS:
    quick              Quick build with all optimizations (recommended)
    platform <name>    Build specific platform (epyc7002, geminilakenk, etc.)
    status            Show system status and build history
    maintenance       Run cache optimization and cleanup
    benchmark         Run performance benchmark tests
    help              Show this help message
    
PERFORMANCE COMMANDS:
    cache-status      Show cache statistics
    cache-clean       Clean old cache files
    cache-warm        Pre-download cache files
    monitor-start     Start build monitoring
    monitor-stop      Stop monitoring and generate report
    
EXAMPLES:
    $0 quick                     # Full optimized build
    $0 platform epyc7002         # Build only epyc7002 platform
    $0 status                    # Check system status
    $0 maintenance               # Run cleanup tasks
    $0 benchmark                 # Test performance

PERFORMANCE FEATURES:
    ⚡ Parallel downloads (up to 75% faster)
    🔄 Multi-platform concurrent builds
    📦 Intelligent cache management
    📊 Real-time performance monitoring
    🧹 Automated cleanup and optimization

ENVIRONMENT VARIABLES:
    MAX_PARALLEL_JOBS=N         Set parallel job limit (default: 4)
    USE_PARALLEL=true|false     Enable/disable parallel builds
    PERFORMANCE_MONITORING      Enable monitoring (default: true)

EOF
}

###############################################################################
# Main execution
case "${1:-help}" in
    "quick")
        print_banner
        check_dependencies
        quick_build
        ;;
    "platform")
        print_banner
        check_dependencies  
        platform_build "$2"
        ;;
    "status")
        show_status
        ;;
    "maintenance")
        print_banner
        maintenance
        ;;
    "benchmark")
        print_banner
        check_dependencies
        benchmark
        ;;
    "cache-status")
        [ -x "${CACHE_MANAGER}" ] && ${CACHE_MANAGER} status
        ;;
    "cache-clean")
        [ -x "${CACHE_MANAGER}" ] && ${CACHE_MANAGER} clean
        ;;
    "cache-warm")
        [ -x "${CACHE_MANAGER}" ] && ${CACHE_MANAGER} warm
        ;;
    "monitor-start")
        [ -x "${PERFORMANCE_MONITOR}" ] && ${PERFORMANCE_MONITOR} start "$2"
        ;;
    "monitor-stop")
        [ -x "${PERFORMANCE_MONITOR}" ] && ${PERFORMANCE_MONITOR} stop "$2"
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac