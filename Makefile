# Makefile for hbwallet

BINARY = hbwallet
LUA = lua
LUAJIT = luajit
HYPE = hype

# Default target
all: build

# Build the binary using Hype
build:
	@echo "Building $(BINARY) with Hype framework..."
	@$(HYPE) build src/hbwallet.lua -o $(BINARY)

# Run tests
test: build
	@echo "Running tests..."
	@$(HYPE) run test/run_tests.lua

# Build and test
test-all: build test

# Clean build artifacts
clean:
	@rm -f $(BINARY)
	@rm -rf build/
	@echo "Cleaned build artifacts"

# Install to /usr/local/bin
install: build
	@echo "Installing $(BINARY) to /usr/local/bin..."
	@sudo cp $(BINARY) /usr/local/bin/
	@echo "Installation complete"

# Uninstall from /usr/local/bin
uninstall:
	@echo "Uninstalling $(BINARY)..."
	@sudo rm -f /usr/local/bin/$(BINARY)
	@echo "Uninstallation complete"

# Create example wallet
example:
	@echo "Creating example wallet..."
	@./$(BINARY) > example-wallet.json
	@echo "Wallet created: example-wallet.json"
	@echo "Getting wallet address..."
	@./$(BINARY) public-key --file example-wallet.json

# Release targets
release:
	@echo "Building release for current platform..."
	@./scripts/build-release.sh current

release-all:
	@echo "Building releases for all platforms..."
	@./scripts/build-release.sh all

.PHONY: all build test test-all clean install uninstall example release release-all
