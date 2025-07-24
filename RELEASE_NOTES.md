# Release Notes - v1.4.0

## hbwallet v1.4.0 - Hype Framework Integration

This release completes the migration to the Hype framework for building and testing, providing better cross-platform support and simpler deployment.

### What's New

- **Hype Framework Integration**: The entire build and test pipeline now uses the Hype framework
- **Improved Cross-Platform Builds**: Native cross-compilation support for all major platforms
- **Enhanced Testing**: Test framework updated to work seamlessly with Hype's runtime
- **Modernized CI/CD**: Updated GitHub Actions workflow for more reliable releases

### Installation

#### Quick Install (Unix-like systems)
```bash
curl -fsSL https://raw.githubusercontent.com/twilson63/hbwallet/main/install.sh | bash
```

#### Manual Installation
1. Download the appropriate binary for your platform from the releases page
2. Extract: `tar -xzf hbwallet-1.4.0-<platform>.tar.gz`
3. Move to PATH: `sudo mv hbwallet /usr/local/bin/`
4. Make executable: `sudo chmod +x /usr/local/bin/hbwallet`

### Supported Platforms

- macOS (Intel & Apple Silicon)
- Linux (amd64, arm64, arm)
- Windows (amd64)

### Usage

```bash
# Generate a new wallet
hbwallet > wallet.json

# Get wallet address
hbwallet public-key --file wallet.json
```

### Verification

All release binaries include SHA256 checksums in `checksums.txt`. Verify your download:

```bash
sha256sum -c checksums.txt
```

### Technical Details

- Built with Hype framework for consistent cross-platform behavior
- 4096-bit RSA keys with PS512 algorithm
- Fully Arweave-compatible JWK format
- Zero external dependencies in release binaries