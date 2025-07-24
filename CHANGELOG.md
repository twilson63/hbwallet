# Changelog

All notable changes to hbwallet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-01

### Added
- Initial release of hbwallet
- JWK RSA key generation (4096-bit, Arweave standard)
- Arweave-compatible wallet address extraction (43 characters)
- Command-line interface with two commands:
  - `hbwallet` - Generate new wallet
  - `hbwallet public-key --file <wallet>` - Extract wallet address
- Cross-platform support (macOS, Linux, Windows)
- Automated build and release system
- Installation script for easy setup
- Comprehensive test suite
- Package manager support (Homebrew, Debian, RPM)

### Technical Details
- Built with Hype framework for single binary distribution
- Uses OpenSSL for cryptographic operations (with pure Lua fallback)
- Implements Arweave's specific JWK format and address generation
- 4096-bit RSA keys (Arweave standard)
- Base64URL encoding for all key components
- SHA256 hashing for address generation

### Security
- Cryptographically secure random number generation
- Standard RSA parameters (e=65537)
- No key material logging or exposure

## [1.1.0] - 2024-01-22

### Changed
- Upgraded to 4096-bit RSA keys (from 2048-bit) to match Arweave standards
- Updated all key generation code to produce proper key sizes
- Fixed standalone binary to generate correct key lengths

### Technical Details
- Modulus (n) and private exponent (d): 683 chars (4096 bits)
- Primes (p, q): 342 chars each (2048 bits)
- Exponents (dp, dq, qi): 342 chars each (2048 bits)

## [1.3.0] - 2025-07-24

### Fixed
- Updated to use Hype 1.7.4's native 4096-bit RSA key generation
- Now generates proper 4096-bit RSA keys for full Arweave compatibility
- Removed dependency on external OpenSSL for key generation

### Changed
- Switched from RS256 to PS512 (RSA-PSS with SHA-512) for enhanced security
- Algorithm provides better cryptographic properties while maintaining compatibility

### Technical Details
- Uses `crypto.generate_jwk("PS512", 4096)` from Hype 1.7.4+
- Pure Lua implementation via Hype framework, no external dependencies
- Verified 512-byte modulus (4096 bits) in generated keys
- PS512 uses RSA-PSS padding scheme with SHA-512 hash

## [Unreleased]

### Planned Features
- Wallet encryption with password
- Import/export in multiple formats
- Signature creation and verification commands
- Integration with Arweave CLI tools
- Hardware wallet support