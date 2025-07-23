# Release Guide for hbwallet

This document describes how to create and distribute releases of hbwallet.

## Prerequisites

- Lua 5.4 or LuaJIT
- Hype framework (optional, for optimized builds)
- Git
- GitHub account with repository access
- GPG key for signing releases (optional)

## Release Process

### 1. Update Version

Update the version in `VERSION` file:
```bash
echo "1.1.0" > VERSION
```

### 2. Run Tests

Ensure all tests pass:
```bash
make test-all
```

### 3. Build Release Binaries

Build for all platforms:
```bash
./scripts/build-release.sh all
```

Or build for current platform only:
```bash
./scripts/build-release.sh current
```

The script will create binaries for:
- macOS (Intel & Apple Silicon)
- Linux (x64, ARM64, ARMv7)
- Windows (x64)

Release files will be in the `release/` directory.

### 4. Create Git Tag

```bash
git add -A
git commit -m "Release v1.1.0"
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin main --tags
```

### 5. GitHub Release

The GitHub Actions workflow will automatically:
1. Build binaries for all platforms
2. Create a GitHub release
3. Upload release assets
4. Generate checksums

You can also trigger manually:
```bash
gh workflow run release.yml -f version=v1.1.0
```

### 6. Update Package Managers

#### Homebrew
1. Update `packaging/homebrew/hbwallet.rb` with new version and SHA256 hashes
2. Submit PR to homebrew-core or your tap

#### Debian/Ubuntu
```bash
cd packaging/debian
VERSION=1.1.0 ARCH=amd64 ./build-deb.sh
```

#### RPM/Fedora
```bash
cd packaging/rpm
rpmbuild -ba hbwallet.spec
```

## Installation Methods

Users can install hbwallet using:

### Quick Install (recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/hbwallet/main/install.sh | bash
```

### Manual Download
1. Go to [Releases](https://github.com/yourusername/hbwallet/releases)
2. Download the appropriate binary for your platform
3. Extract and install:
   ```bash
   tar -xzf hbwallet-*.tar.gz
   sudo mv hbwallet /usr/local/bin/
   sudo chmod +x /usr/local/bin/hbwallet
   ```

### Package Managers

#### Homebrew (macOS/Linux)
```bash
brew tap yourusername/hbwallet
brew install hbwallet
```

#### Debian/Ubuntu
```bash
wget https://github.com/yourusername/hbwallet/releases/download/v1.0.0/hbwallet_1.0.0_amd64.deb
sudo dpkg -i hbwallet_1.0.0_amd64.deb
```

#### Build from Source
```bash
git clone https://github.com/yourusername/hbwallet.git
cd hbwallet
make build
sudo make install
```

## Verifying Releases

All releases include a `checksums.txt` file with SHA256 hashes:

```bash
# Download checksums
curl -LO https://github.com/yourusername/hbwallet/releases/download/v1.0.0/checksums.txt

# Verify your download
sha256sum -c checksums.txt --ignore-missing
```

## Release Checklist

- [ ] Update VERSION file
- [ ] Run all tests
- [ ] Update CHANGELOG.md
- [ ] Build release binaries
- [ ] Test binaries on each platform
- [ ] Create git tag
- [ ] Push tag to trigger GitHub release
- [ ] Verify GitHub release and downloads
- [ ] Update package manager configs
- [ ] Announce release

## Troubleshooting

### Build Issues

If Hype is not available, the build script falls back to a standalone Lua build.

### Platform-Specific Notes

**macOS**: Binaries may need to be signed for Gatekeeper.
```bash
codesign --sign "Developer ID" hbwallet
```

**Windows**: Consider providing a PowerShell install script.

**Linux**: Ensure binaries are statically linked or document dependencies.

## Support

For issues with releases:
1. Check GitHub Issues
2. Contact maintainers
3. Submit a bug report