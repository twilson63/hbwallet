#!/bin/bash

# Build Debian package for hbwallet

set -e

VERSION=${VERSION:-1.0.0}
ARCH=${ARCH:-amd64}
PKG_NAME="hbwallet_${VERSION}_${ARCH}"

# Create package structure
mkdir -p "${PKG_NAME}/DEBIAN"
mkdir -p "${PKG_NAME}/usr/local/bin"

# Copy binary
cp ../../release/hbwallet-${VERSION}-linux-${ARCH} "${PKG_NAME}/usr/local/bin/hbwallet"
chmod 755 "${PKG_NAME}/usr/local/bin/hbwallet"

# Create control file
cat > "${PKG_NAME}/DEBIAN/control" << EOF
Package: hbwallet
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: Your Name <your.email@example.com>
Description: Arweave JWK wallet generator
 hbwallet is a command-line tool for generating JWK (JSON Web Key)
 wallets compatible with Arweave blockchain. It creates RSA keypairs
 and extracts 43-character wallet addresses.
Homepage: https://github.com/yourusername/hbwallet
EOF

# Create postinst script
cat > "${PKG_NAME}/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

echo "hbwallet has been installed successfully!"
echo ""
echo "Usage:"
echo "  hbwallet                      # Generate new wallet"
echo "  hbwallet public-key --file wallet.json  # Get wallet address"

exit 0
EOF
chmod 755 "${PKG_NAME}/DEBIAN/postinst"

# Build the package
dpkg-deb --build "${PKG_NAME}"

echo "Debian package created: ${PKG_NAME}.deb"