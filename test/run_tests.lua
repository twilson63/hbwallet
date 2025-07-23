#!/usr/bin/env lua

-- Main test runner for hbwallet

print("==============================================")
print("           hbwallet Test Suite                ")
print("==============================================")

-- Load test framework
local test = require("test.test_framework")

-- Check if binary exists
local function check_binary()
    local f = io.open("./hbwallet", "r")
    if not f then
        print("\nError: hbwallet binary not found!")
        print("Please build the project first using:")
        print("  make build")
        print("  or")
        print("  hype build")
        os.exit(1)
    end
    f:close()
end

-- Run all test suites
local function run_all_tests()
    -- Check binary exists
    check_binary()
    
    -- Run test suites
    require("test.test_jwk_generation")
    require("test.test_address_extraction")
    require("test.test_crypto_signatures")
    
    -- Show summary and exit
    local exit_code = test.summary()
    os.exit(exit_code)
end

-- Run tests
run_all_tests()