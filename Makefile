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
	@$(HYPE) build src/hbwallet.lua -o $(BINARY) || $(MAKE) build-manual

# Alternative: Build with LuaJIT directly
build-luajit:
	@echo "Building $(BINARY) with LuaJIT..."
	@echo '#!/usr/bin/env luajit' > $(BINARY)
	@luajit -b src/hbwallet.lua - >> $(BINARY)
	@chmod +x $(BINARY)

# Run tests
test: build
	@echo "Running tests..."
	@export LUA_PATH="./?.lua;./?/init.lua;$$LUA_PATH" && $(LUA) test/run_tests.lua

# Build and test
test-all:
	@./test/build_and_test.sh

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

# Manual build fallback
build-manual:
	@echo "Building $(BINARY) manually..."
	@echo '#!/usr/bin/env lua' > $(BINARY)
	@echo 'package.path = package.path .. ";./?.lua"' >> $(BINARY)
	@cat src/hbwallet.lua >> $(BINARY)
	@chmod +x $(BINARY)
	@echo "Manual build complete"

.PHONY: all build build-luajit build-manual test clean install uninstall example release release-all