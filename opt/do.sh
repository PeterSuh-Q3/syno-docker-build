#!/bin/bash
# Synology Compiler Entrypoint Script
# Usage: docker run ... dante90/syno-compiler:7.3-{platform} compile-module {platform}

set -e

ACTION="${1}"
PLATFORM="${2}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Verify toolchain exists
if [ ! -d "/opt/synology" ] && [ ! -f "/opt/toolchain.tar" ] && [ ! -d "/opt/x86_64-pc-linux-gnu" ]; then
    log_error "Toolchain not found in /opt"
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

case "${ACTION}" in
    compile-module)
        if [ -z "${PLATFORM}" ]; then
            log_error "Platform not specified"
            echo "Usage: ${ACTION} {platform}"
            exit 1
        fi

        log_info "Compiling modules for platform: ${PLATFORM}"
        log_info "Architecture: ${ARCH}"
        log_info "Toolchain version: ${TOOLCHAIN_VERSION}"

        # Set up environment variables for cross-compilation
        export PATH="/opt/bin:${PATH}"
        export LD_LIBRARY_PATH="/opt/lib:${LD_LIBRARY_PATH}"

        # Module compilation logic would go here
        # This is a placeholder - actual compilation depends on your module structure
        log_info "Module compilation started..."

        # Find and compile modules
        if [ -d "/input" ] && [ "$(ls -A /input)" ]; then
            log_info "Found input files in /input"

            # Example: compile any C/C++ sources
            find /input -name "*.c" -o -name "*.cpp" | while read -r source; do
                log_info "Processing: ${source}"
            done

            log_info "Compilation completed"
        else
            log_warn "No input files found in /input"
        fi
        ;;

    shell)
        log_info "Starting interactive shell"
        /bin/bash
        ;;

    *)
        log_error "Unknown action: ${ACTION}"
        echo "Available actions:"
        echo "  compile-module {platform}  - Compile modules for specified platform"
        echo "  shell                      - Start interactive shell"
        exit 1
        ;;
esac

log_info "Done"
exit 0
