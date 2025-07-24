# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Commands

### Build Commands
```bash
# Build the hbwallet binary using Hype framework
make build

# Build release binaries for all platforms
make release-all     # Build for darwin, linux, windows (all architectures)
make release         # Build for current platform only
```

### Testing Commands
```bash
# Run the test suite
make test

# Build and test in one command
make test-all
```

### Development Commands
```bash
# Install hbwallet to /usr/local/bin
make install

# Clean build artifacts
make clean

# Create example wallet and display address
make example
```

## Architecture Overview

hbwallet is a lightweight Arweave JWK wallet generator built with the Hype framework. The codebase is structured to support multiple build methods and platforms.

### Key Components

1. **Main Implementation** (`src/hbwallet.lua`, `main.lua`):
   - Self-contained Lua application with embedded JSON, Base64, and crypto implementations
   - Uses Hype framework's crypto module for RSA key generation (PS512, 4096-bit)
   - Generates standard JWK format compatible with Arweave blockchain

2. **Build System**:
   - Primary: Hype framework build (`hype build`)
   - Cross-platform release builds via `scripts/build-release.sh`

3. **Test Framework** (`test/`):
   - Custom test runner in `test/run_tests.lua`
   - Test suites for JWK generation, address extraction, and crypto signatures
   - Tests validate Arweave compatibility and cryptographic correctness

4. **Distribution**:
   - Single binary executables for each platform
   - Automated GitHub Actions workflow for releases
   - Platform packages (Homebrew, Debian, RPM) in `packaging/`

### Security Considerations

- Generates 4096-bit RSA keys with PS512 algorithm
- Uses system entropy for cryptographic security
- Validates file paths to prevent directory traversal
- Implements size limits on file operations

### Arweave Address Generation

Addresses are computed as: `base64url(SHA256(base64url_decode(jwk.n)))`
Where `jwk.n` is the RSA public modulus.

## Common Development Tasks

When modifying crypto implementations, ensure compatibility with:
- Arweave mainnet/testnet requirements
- ArConnect wallet format
- Standard JWK RFC 7517 specification

The codebase prioritizes minimal dependencies and cross-platform compatibility.
