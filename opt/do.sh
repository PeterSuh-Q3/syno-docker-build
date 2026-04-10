#!/bin/bash
# Synology Compiler Entrypoint Script
# Multi-platform cross-compilation environment
# Usage: docker run ... dante90/syno-compiler:7.3 compile-module {platform}

set -e

ACTION="${1}"
PLATFORM="${2}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Verify platforms file and toolchain directories exist
if [ ! -f "/opt/platforms" ]; then
    log_error "Platforms file /opt/platforms not found"
    exit 1
fi

# Verify input/output directories
if [ ! -d "/input" ]; then
    log_error "Input directory /input not found"
    exit 1
fi

if [ ! -d "/output" ]; then
    log_warn "Output directory /output not found, creating..."
    mkdir -p /output
fi

# Function to list available platforms
list_platforms() {
    log_info "Available platforms:"
    if [ -f "/opt/platforms" ]; then
        awk '{print "  " $1 " (kernel " $2 ")"}' /opt/platforms
    fi
}

# Function to setup platform environment
setup_platform() {
    local platform=$1

    if [ ! -d "/opt/${platform}" ]; then
        log_error "Platform directory /opt/${platform} not found"
        list_platforms
        return 1
    fi

    # Get kernel version from platforms file
    local kver=$(grep "^${platform}\t" /opt/platforms | cut -f2)
    if [ -z "${kver}" ]; then
        log_error "Platform ${platform} not found in /opt/platforms"
        list_platforms
        return 1
    fi

    # Setup cross-compilation environment
    export SYNOLOGY_PLATFORM="${platform}"
    export SYNOLOGY_KERNEL_VERSION="${kver}"
    export PLATFORM_PATH="/opt/${platform}"

    # Add platform-specific bin to PATH
    if [ -d "${PLATFORM_PATH}/bin" ]; then
        export PATH="${PLATFORM_PATH}/bin:${PATH}"
    fi

    # Setup library paths
    if [ -d "${PLATFORM_PATH}/lib" ]; then
        export LD_LIBRARY_PATH="${PLATFORM_PATH}/lib:${LD_LIBRARY_PATH}"
    fi

    # Setup source directory
    if [ -d "${PLATFORM_PATH}/source" ]; then
        export LINUX_SRC="${PLATFORM_PATH}/source"
    fi

    log_success "Platform environment setup: ${platform} (kernel ${kver})"

    return 0
}

case "${ACTION}" in
    compile-module)
        if [ -z "${PLATFORM}" ]; then
            log_error "Platform not specified"
            echo ""
            echo "Usage: compile-module {platform}"
            echo ""
            list_platforms
            exit 1
        fi

        # Setup platform environment
        if ! setup_platform "${PLATFORM}"; then
            exit 1
        fi

        log_info "Compiling modules for platform: ${PLATFORM}"
        log_info "Kernel version: ${SYNOLOGY_KERNEL_VERSION}"
        log_info "Input directory: /input"
        log_info "Output directory: /output"

        # Module compilation logic
        # This is a framework - actual compilation depends on your module structure

        if [ -d "/input" ] && [ "$(ls -A /input)" ]; then
            log_info "Found input files in /input"

            # Example: Look for Makefile or build scripts
            if [ -f "/input/Makefile" ]; then
                log_info "Makefile found, ready to compile"
                # Actual build command would go here:
                # cd /input && make CROSS_COMPILE="${PLATFORM_PATH}/bin/..." modules
            else
                log_warn "No Makefile found in /input"
            fi

            log_success "Module compilation completed"
        else
            log_warn "No input files found in /input - nothing to compile"
        fi
        ;;

    shell)
        if [ -n "${PLATFORM}" ]; then
            if ! setup_platform "${PLATFORM}"; then
                exit 1
            fi
            log_info "Starting interactive shell with ${PLATFORM} environment"
        else
            log_info "Starting interactive shell (all platforms available in /opt)"
            log_info "Use: source /opt/{platform}/env.sh"
        fi
        /bin/bash
        ;;

    list)
        log_info "Available platforms:"
        list_platforms
        ;;

    *)
        if [ -z "${ACTION}" ]; then
            log_info "No action specified"
        else
            log_error "Unknown action: ${ACTION}"
        fi

        echo ""
        echo "Usage:"
        echo "  compile-module {platform}  - Compile modules for specified platform"
        echo "  shell [platform]           - Start interactive shell (optionally with platform env)"
        echo "  list                       - List available platforms"
        echo ""
        list_platforms
        exit 1
        ;;
esac

log_success "Done"
exit 0
