#!/bin/bash
# Build Synology Compiler Docker images for all x86_64 platforms
# Usage: ./scripts/build-all-platforms.sh [push]
# - push: 'true' to push to Docker Hub, 'false' for local build only (default: false)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PUSH=${1:-false}
REGISTRY="docker.io"
REPOSITORY="dante90/syno-compiler"
TOOLCHAIN_VERSION="7.3"

# All x86_64 platforms
PLATFORMS=(
    "apollolake"
    "avoton"
    "braswell"
    "broadwell"
    "broadwellnk"
    "broadwellnkv2"
    "broadwellntbap"
    "bromolow"
    "denverton"
    "epyc7002"
    "geminilake"
    "geminilakenk"
    "grantley"
    "kvmx64"
    "purley"
    "r1000"
    "r1000nk"
    "v1000"
    "v1000nk"
)

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

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Login to Docker Hub if pushing
if [ "$PUSH" = "true" ]; then
    log_info "Attempting to login to Docker Hub..."
    if ! docker login; then
        log_error "Failed to login to Docker Hub"
        exit 1
    fi
fi

log_info "Building Synology Compiler ${TOOLCHAIN_VERSION} for ${#PLATFORMS[@]} platforms"
log_info "Push to Docker Hub: $PUSH"
echo ""

SUCCESSFUL=0
FAILED=0
FAILED_PLATFORMS=()

for PLATFORM in "${PLATFORMS[@]}"; do
    log_info "Building for platform: $PLATFORM"

    IMAGE_TAG="${REGISTRY}/${REPOSITORY}:${TOOLCHAIN_VERSION}-${PLATFORM}"

    # Build image
    if docker build \
        -t "$IMAGE_TAG" \
        --build-arg PLATFORM="$PLATFORM" \
        --build-arg TOOLCHAIN_VERSION="$TOOLCHAIN_VERSION" \
        -f "$REPO_DIR/Dockerfile" \
        "$REPO_DIR"; then

        log_success "Build successful for $PLATFORM"

        # Push if requested
        if [ "$PUSH" = "true" ]; then
            log_info "Pushing $IMAGE_TAG to Docker Hub..."
            if docker push "$IMAGE_TAG"; then
                log_success "Push successful for $PLATFORM"
                ((SUCCESSFUL++))
            else
                log_error "Push failed for $PLATFORM"
                FAILED_PLATFORMS+=("$PLATFORM")
                ((FAILED++))
            fi
        else
            log_info "Skipping push (local build only)"
            ((SUCCESSFUL++))
        fi

    else
        log_error "Build failed for $PLATFORM"
        FAILED_PLATFORMS+=("$PLATFORM")
        ((FAILED++))
    fi

    echo ""
done

# Summary
echo "========================================="
log_info "Build Summary"
echo "========================================="
log_success "Successful: $SUCCESSFUL"
log_error "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    log_error "Failed platforms:"
    for PLATFORM in "${FAILED_PLATFORMS[@]}"; do
        echo "  - $PLATFORM"
    done
    exit 1
else
    log_success "All platforms built successfully!"
    if [ "$PUSH" = "true" ]; then
        log_success "All images pushed to Docker Hub"
    fi
fi

# Update 'latest' and '7.3' tags (point to broadwell as default)
if [ "$PUSH" = "true" ] && [ "$SUCCESSFUL" -eq "${#PLATFORMS[@]}" ]; then
    log_info "Updating 'latest' and '7.3' tags..."

    BROADWELL_TAG="${REGISTRY}/${REPOSITORY}:${TOOLCHAIN_VERSION}-broadwell"
    LATEST_TAG="${REGISTRY}/${REPOSITORY}:latest"
    VERSION_TAG="${REGISTRY}/${REPOSITORY}:${TOOLCHAIN_VERSION}"

    # Tag broadwell image
    docker tag "$BROADWELL_TAG" "$VERSION_TAG"
    docker tag "$BROADWELL_TAG" "$LATEST_TAG"

    # Push new tags
    if docker push "$VERSION_TAG" && docker push "$LATEST_TAG"; then
        log_success "Updated tags: $VERSION_TAG, $LATEST_TAG"
    else
        log_error "Failed to update version/latest tags"
        exit 1
    fi
fi

echo "========================================="
exit 0
