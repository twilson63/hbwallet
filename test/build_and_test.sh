#!/bin/bash

# Build and test script for hbwallet

set -e  # Exit on error

echo "=============================================="
echo "      hbwallet Build and Test Script         "
echo "=============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${YELLOW}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check for dependencies
print_status "Checking dependencies..."

# Check for Hype (required)
if ! command -v hype &> /dev/null; then
    print_error "Hype framework not found!"
    echo "    Please install Hype to build and test hbwallet"
    echo "    Visit: https://github.com/ryanpwaldon/hype"
    exit 1
fi
print_success "Hype framework found"

# Check for Lua/LuaJIT
if command -v lua &> /dev/null; then
    print_success "Lua found: $(lua -v 2>&1 | head -n1)"
elif command -v luajit &> /dev/null; then
    print_success "LuaJIT found: $(luajit -v 2>&1 | head -n1)"
else
    print_error "Neither Lua nor LuaJIT found!"
    exit 1
fi

echo ""

# Build the project
print_status "Building hbwallet with Hype..."

# Build with Hype
hype build src/hbwallet.lua -o hbwallet
if [ $? -eq 0 ]; then
    print_success "Build successful with Hype"
else
    print_error "Hype build failed!"
    exit 1
fi

# Make sure binary is executable
chmod +x hbwallet

echo ""

# Run tests
print_status "Running tests..."
echo ""

# Set up Lua path for tests
export LUA_PATH="./?.lua;./?/init.lua;$LUA_PATH"

# Run the test suite with Hype
hype run test/run_tests.lua

TEST_EXIT_CODE=$?

echo ""

# Summary
if [ $TEST_EXIT_CODE -eq 0 ]; then
    print_success "All tests passed!"
    echo ""
    echo "You can now use hbwallet:"
    echo "  ./hbwallet                    # Generate new wallet"
    echo "  ./hbwallet public-key --file wallet.json  # Get address"
else
    print_error "Some tests failed!"
    exit $TEST_EXIT_CODE
fi