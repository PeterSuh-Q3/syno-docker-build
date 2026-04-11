#!/usr/bin/env bash

# Docker Hub Setup and Management Tool
# Handles Docker Hub authentication for local builds and GitHub Actions

DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-dante90}"
DOCKER_HUB_REPO="${DOCKER_HUB_REPO:-syno-compiler}"
CONFIG_FILE="$HOME/.docker-hub-config"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

function log_note() {
    echo -e "${BLUE}[NOTE]${NC} $1"
}

###############################################################################
function show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                 🐳 Docker Hub Setup Manager                   ║
║              Synology Docker Build Integration               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

###############################################################################
function check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    log_info "✅ Docker is available and running"
    return 0
}

###############################################################################
function save_config() {
    local username="$1"
    local repo="$2"
    
    cat > "$CONFIG_FILE" << EOF
# Docker Hub Configuration for Synology Build
DOCKER_HUB_USERNAME="$username"
DOCKER_HUB_REPO="$repo"
DOCKER_HUB_IMAGE="$username/$repo"
CONFIG_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    
    chmod 600 "$CONFIG_FILE"
    log_info "Configuration saved to $CONFIG_FILE"
}

###############################################################################
function load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

###############################################################################
function setup_docker_hub_account() {
    show_banner
    log_info "Setting up Docker Hub account configuration..."
    
    echo ""
    echo "📋 You'll need:"
    echo "   1. Docker Hub account (free or paid)"
    echo "   2. Docker Hub username"  
    echo "   3. Access Token or Password"
    echo ""
    
    # Get username
    local username=""
    while [ -z "$username" ]; do
        read -p "🔑 Enter your Docker Hub username: " username
        if [ -z "$username" ]; then
            log_warn "Username cannot be empty"
        fi
    done
    
    # Get repository name
    local repo=""
    echo ""
    echo "📦 Repository name (default: syno-compiler):"
    read -p "   Enter repository name [syno-compiler]: " repo
    repo=${repo:-syno-compiler}
    
    # Confirm setup
    echo ""
    log_info "Configuration Summary:"
    echo "   Username: $username"
    echo "   Repository: $repo"
    echo "   Full Image Name: $username/$repo"
    echo ""
    
    read -p "Continue with this configuration? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "Setup cancelled"
        return 1
    fi
    
    # Save configuration
    save_config "$username" "$repo"
    
    # Test Docker Hub connection
    log_info "Testing Docker Hub connection..."
    if docker_login_interactive; then
        log_info "🎉 Docker Hub setup completed successfully!"
        
        # Update build scripts with new image name
        update_build_scripts "$username/$repo"
        
        echo ""
        log_note "Next steps:"
        echo "   1. For GitHub Actions: Set up GitHub Secrets"
        echo "   2. Run: ./docker-hub-manager.sh github-setup"
        echo "   3. Test with: ./build-manager.sh quick"
        
    else
        log_error "Docker Hub connection failed"
        return 1
    fi
}

###############################################################################
function docker_login_interactive() {
    echo ""
    log_info "🔐 Docker Hub Authentication Required"
    echo ""
    echo "Please choose authentication method:"
    echo "   1. Username + Password"
    echo "   2. Username + Access Token (Recommended)"
    echo ""
    
    read -p "Select option (1 or 2): " auth_method
    
    case "$auth_method" in
        "1")
            log_info "Using username + password authentication"
            docker login
            ;;
        "2")
            log_info "Using username + access token authentication"
            echo ""
            log_note "To create an Access Token:"
            echo "   1. Go to https://hub.docker.com/settings/security"
            echo "   2. Click 'New Access Token'"
            echo "   3. Give it a name (e.g., 'Synology Build')"
            echo "   4. Copy the token and use it as password below"
            echo ""
            docker login
            ;;
        *)
            log_error "Invalid option"
            return 1
            ;;
    esac
}

###############################################################################
function update_build_scripts() {
    local new_image_name="$1"
    
    log_info "Updating build scripts with new image name: $new_image_name"
    
    # Update build-parallel.sh
    if [ -f "build-parallel.sh" ]; then
        sed -i "s/dante90\/syno-compiler/$new_image_name/g" build-parallel.sh
        log_info "✅ Updated build-parallel.sh"
    fi
    
    # Update build-manager.sh  
    if [ -f "build-manager.sh" ]; then
        sed -i "s/dante90\/syno-compiler/$new_image_name/g" build-manager.sh
        log_info "✅ Updated build-manager.sh"
    fi
    
    # Update GitHub Actions workflow
    if [ -f ".github/workflows/build-parallel.yml" ]; then
        sed -i "s/dante90\/syno-compiler/$new_image_name/g" .github/workflows/build-parallel.yml
        log_info "✅ Updated GitHub Actions workflow"
    fi
    
    # Update original build.sh
    if [ -f "build.sh" ]; then
        sed -i "s/dante90\/syno-compiler/$new_image_name/g" build.sh
        log_info "✅ Updated build.sh"
    fi
}

###############################################################################
function github_secrets_setup() {
    show_banner
    log_info "GitHub Secrets Setup Guide"
    
    if ! load_config; then
        log_error "No Docker Hub configuration found. Run 'setup' first."
        return 1
    fi
    
    echo ""
    echo "🔐 GitHub Secrets Required for CI/CD:"
    echo ""
    echo "   DOCKER_USERNAME = $DOCKER_HUB_USERNAME"
    echo "   DOCKER_PASSWORD = <your-docker-hub-token-or-password>"
    echo ""
    
    echo "📝 How to add GitHub Secrets:"
    echo "   1. Go to your GitHub repository"
    echo "   2. Click Settings → Secrets and variables → Actions"
    echo "   3. Click 'New repository secret'"
    echo "   4. Add both secrets above"
    echo ""
    
    echo "🎯 Access Token Creation (Recommended):"
    echo "   1. Visit: https://hub.docker.com/settings/security"
    echo "   2. Click 'New Access Token'"
    echo "   3. Name: 'GitHub Actions - Synology Build'"
    echo "   4. Permissions: Read, Write, Delete"
    echo "   5. Copy token → Use as DOCKER_PASSWORD"
    echo ""
    
    read -p "Press Enter after setting up GitHub Secrets..."
    
    log_info "GitHub Secrets setup guide completed!"
    log_note "You can now use GitHub Actions workflow: build-parallel.yml"
}

###############################################################################
function check_login_status() {
    log_info "Checking Docker Hub login status..."
    
    if load_config; then
        echo "📋 Current Configuration:"
        echo "   Username: $DOCKER_HUB_USERNAME"
        echo "   Repository: $DOCKER_HUB_REPO"
        echo "   Image: $DOCKER_HUB_IMAGE"
        echo ""
    else
        log_warn "No configuration found"
    fi
    
    # Test Docker login
    local current_user=$(docker info 2>/dev/null | grep "Username:" | cut -d' ' -f2)
    
    if [ -n "$current_user" ]; then
        log_info "✅ Docker Hub login active"
        echo "   Logged in as: $current_user"
        
        # Test push access
        echo ""
        log_info "Testing repository push access..."
        local test_tag="${DOCKER_HUB_IMAGE:-dante90/syno-compiler}:test-$(date +%s)"
        
        if docker tag hello-world "$test_tag" 2>/dev/null && docker push "$test_tag" 2>/dev/null; then
            log_info "✅ Push access confirmed"
            docker rmi "$test_tag" >/dev/null 2>&1
        else
            log_warn "❌ Push access failed or repository doesn't exist"
        fi
        
    else
        log_warn "⚠️  Not logged into Docker Hub"
        echo "   Run: ./docker-hub-manager.sh login"
    fi
}

###############################################################################
function quick_login() {
    log_info "Quick Docker Hub login..."
    
    if load_config; then
        echo "Username: $DOCKER_HUB_USERNAME"
        docker_login_interactive
    else
        log_warn "No configuration found. Run 'setup' first for guided configuration."
        docker_login_interactive
    fi
}

###############################################################################
function logout_docker() {
    log_info "Logging out from Docker Hub..."
    docker logout
    log_info "✅ Logged out from Docker Hub"
}

###############################################################################
function show_help() {
    show_banner
    cat << EOF
🐳 Docker Hub Setup and Management Tool

USAGE:
    $0 [command]

COMMANDS:
    setup           Complete Docker Hub account setup (recommended for first time)
    login           Quick Docker Hub login
    logout          Logout from Docker Hub
    status          Check current login status and configuration
    github-setup    Guide for setting up GitHub Secrets
    test-push       Test image push to Docker Hub
    help            Show this help message

FIRST TIME SETUP:
    1. ./docker-hub-manager.sh setup        # Configure account
    2. ./docker-hub-manager.sh github-setup # Set up CI/CD
    3. ./build-manager.sh quick              # Test build

DAILY USAGE:
    ./docker-hub-manager.sh status          # Check login status
    ./docker-hub-manager.sh login           # Login if needed

TROUBLESHOOTING:
    - Authentication errors: Use Access Token instead of password
    - Push failures: Check repository exists and you have write access
    - GitHub Actions failures: Verify DOCKER_USERNAME and DOCKER_PASSWORD secrets

ACCESS TOKEN SETUP:
    1. Visit: https://hub.docker.com/settings/security
    2. Create new token with Read/Write/Delete permissions
    3. Use token as password for docker login

EOF
}

###############################################################################
function test_push() {
    log_info "Testing Docker Hub push capability..."
    
    if ! load_config; then
        log_error "No configuration found. Run 'setup' first."
        return 1
    fi
    
    # Create a tiny test image
    local test_tag="${DOCKER_HUB_IMAGE}:test-$(date +%s)"
    
    echo "Creating test image: $test_tag"
    
    # Create minimal test image
    cat > Dockerfile.test << 'EOF'
FROM alpine:latest
RUN echo "Docker Hub push test successful" > /test.txt
CMD cat /test.txt
EOF
    
    if docker build -f Dockerfile.test -t "$test_tag" . && \
       docker push "$test_tag"; then
        log_info "✅ Docker Hub push test successful!"
        
        # Cleanup
        docker rmi "$test_tag" >/dev/null 2>&1
        rm -f Dockerfile.test
        
        log_note "Your Docker Hub setup is working correctly"
        return 0
    else
        log_error "❌ Docker Hub push test failed"
        rm -f Dockerfile.test
        return 1
    fi
}

###############################################################################
# Main execution
case "${1:-help}" in
    "setup")
        check_docker && setup_docker_hub_account
        ;;
    "login")
        check_docker && quick_login
        ;;
    "logout")
        check_docker && logout_docker
        ;;
    "status")
        check_docker && check_login_status
        ;;
    "github-setup")
        github_secrets_setup
        ;;
    "test-push")
        check_docker && test_push
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