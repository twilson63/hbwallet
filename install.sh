#!/bin/bash

# Install script for hbwallet
# This script downloads and installs the latest release of hbwallet

set -e

# Configuration
REPO="hbwallet/hbwallet"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
TEMP_DIR=$(mktemp -d)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Detect OS and architecture
detect_platform() {
    local os=""
    local arch=""
    
    # Detect OS
    case "$(uname -s)" in
        Darwin*)
            os="darwin"
            ;;
        Linux*)
            os="linux"
            ;;
        *)
            print_error "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
    
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l|armhf)
            arch="arm"
            ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    
    echo "${os}-${arch}"
}

# Check for required tools
check_requirements() {
    local missing_tools=()
    
    for tool in curl tar; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install them and try again"
        exit 1
    fi
}

# Get latest release version
get_latest_version() {
    if [ -n "$VERSION" ]; then
        echo "$VERSION"
        return
    fi
    
    print_info "Fetching latest version..."
    
    # For local development/testing
    if [ -f "VERSION" ]; then
        cat VERSION
        return
    fi
    
    # Get from GitHub releases
    local latest_url="https://api.github.com/repos/${REPO}/releases/latest"
    local version=$(curl -sL "$latest_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$version" ]; then
        print_warning "Could not fetch latest version, using v1.0.0"
        version="v1.0.0"
    fi
    
    echo "$version"
}

# Download release
download_release() {
    local version=$1
    local platform=$2
    
    # Remove 'v' prefix if present
    version="${version#v}"
    
    local filename="hbwallet-${version}-${platform}.tar.gz"
    
    # For local testing, check release directory
    if [ -d "release" ] && [ -f "release/$filename" ]; then
        print_info "Using local release file"
        cp "release/$filename" "$TEMP_DIR/"
        return 0
    fi
    
    local url="https://github.com/${REPO}/releases/download/v${version}/${filename}"
    
    print_info "Downloading $filename..."
    
    if ! curl -L -o "$TEMP_DIR/$filename" "$url"; then
        print_error "Failed to download release"
        print_info "URL: $url"
        return 1
    fi
    
    print_success "Downloaded successfully"
}

# Verify checksum
verify_checksum() {
    local version=$1
    local platform=$2
    
    # Remove 'v' prefix if present
    version="${version#v}"
    
    local filename="hbwallet-${version}-${platform}.tar.gz"
    local checksums_url="https://github.com/${REPO}/releases/download/v${version}/checksums.txt"
    
    # For local testing
    if [ -f "release/checksums.txt" ]; then
        cp "release/checksums.txt" "$TEMP_DIR/"
    else
        print_info "Downloading checksums..."
        if ! curl -sL -o "$TEMP_DIR/checksums.txt" "$checksums_url"; then
            print_warning "Could not download checksums, skipping verification"
            return 0
        fi
    fi
    
    cd "$TEMP_DIR"
    
    if command -v sha256sum &> /dev/null; then
        if sha256sum -c checksums.txt --ignore-missing 2>/dev/null | grep -q "$filename: OK"; then
            print_success "Checksum verified"
        else
            print_warning "Checksum verification failed"
        fi
    elif command -v shasum &> /dev/null; then
        if shasum -a 256 -c checksums.txt --ignore-missing 2>/dev/null | grep -q "$filename: OK"; then
            print_success "Checksum verified"
        else
            print_warning "Checksum verification failed"
        fi
    else
        print_warning "No checksum tool available, skipping verification"
    fi
    
    cd - > /dev/null
}

# Install binary
install_binary() {
    local version=$1
    local platform=$2
    
    # Remove 'v' prefix if present
    version="${version#v}"
    
    local filename="hbwallet-${version}-${platform}.tar.gz"
    local binary_name="hbwallet-${version}-${platform%%-*}-${platform##*-}"
    
    cd "$TEMP_DIR"
    
    print_info "Extracting archive..."
    tar -xzf "$filename"
    
    # Find the binary (might have different names)
    local binary=""
    for name in "hbwallet" "$binary_name" "hbwallet-"*; do
        if [ -f "$name" ] && [ -x "$name" ]; then
            binary="$name"
            break
        fi
    done
    
    if [ -z "$binary" ]; then
        print_error "Could not find hbwallet binary in archive"
        return 1
    fi
    
    # Check if we need sudo
    if [ -w "$INSTALL_DIR" ]; then
        print_info "Installing to $INSTALL_DIR/hbwallet..."
        mv "$binary" "$INSTALL_DIR/hbwallet"
        chmod +x "$INSTALL_DIR/hbwallet"
    else
        print_info "Installing to $INSTALL_DIR/hbwallet (requires sudo)..."
        sudo mv "$binary" "$INSTALL_DIR/hbwallet"
        sudo chmod +x "$INSTALL_DIR/hbwallet"
    fi
    
    cd - > /dev/null
    
    print_success "Installation complete!"
}

# Verify installation
verify_installation() {
    if command -v hbwallet &> /dev/null; then
        print_success "hbwallet is now available in your PATH"
        print_info "Version: $(hbwallet --version 2>/dev/null || echo "unknown")"
        echo ""
        print_info "You can now use hbwallet:"
        echo "  hbwallet                      # Generate new wallet"
        echo "  hbwallet public-key --file wallet.json  # Get wallet address"
    else
        print_warning "hbwallet was installed to $INSTALL_DIR but is not in your PATH"
        print_info "Add $INSTALL_DIR to your PATH or run: $INSTALL_DIR/hbwallet"
    fi
}

# Main installation flow
main() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║     hbwallet Installation Script      ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                VERSION="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --version VERSION     Install specific version (default: latest)"
                echo "  --install-dir DIR     Installation directory (default: /usr/local/bin)"
                echo "  --help, -h           Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Check requirements
    check_requirements
    
    # Detect platform
    PLATFORM=$(detect_platform)
    print_info "Detected platform: $PLATFORM"
    
    # Get version
    VERSION=$(get_latest_version)
    print_info "Installing version: $VERSION"
    
    # Download release
    if ! download_release "$VERSION" "$PLATFORM"; then
        print_error "Installation failed"
        exit 1
    fi
    
    # Verify checksum
    verify_checksum "$VERSION" "$PLATFORM"
    
    # Install
    if ! install_binary "$VERSION" "$PLATFORM"; then
        print_error "Installation failed"
        exit 1
    fi
    
    # Verify
    verify_installation
    
    echo ""
    print_success "Installation completed successfully!"
}

# Run main function
main "$@"