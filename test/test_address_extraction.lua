-- Tests for 43-character address extraction

local test = require("test.test_framework")
local json = require("test.json")

test.suite("Address Extraction", {
    ["Extract address from wallet file"] = function()
        -- Generate a wallet
        local wallet_output = test.run_command("./hbwallet")
        local jwk = json.decode(wallet_output)
        
        -- Save to temporary file
        local wallet_file = test.temp_file(wallet_output)
        
        -- Extract address
        local address_output, success = test.run_command("./hbwallet public-key --file " .. wallet_file)
        test.assert_true(success, "public-key command should succeed")
        
        -- Remove newline
        local address = address_output:gsub("%s+$", "")
        
        -- Verify address format
        test.assert_length(address, 43, "Address should be exactly 43 characters")
        test.assert_matches(address, "^[A-Za-z0-9_-]+$", "Address should be base64url encoded")
        
        -- Cleanup
        test.cleanup(wallet_file)
    end,
    
    ["Same wallet produces same address"] = function()
        -- Generate a wallet
        local wallet_output = test.run_command("./hbwallet")
        local wallet_file = test.temp_file(wallet_output)
        
        -- Extract address multiple times
        local address1 = test.run_command("./hbwallet public-key --file " .. wallet_file):gsub("%s+$", "")
        local address2 = test.run_command("./hbwallet public-key --file " .. wallet_file):gsub("%s+$", "")
        local address3 = test.run_command("./hbwallet public-key --file " .. wallet_file):gsub("%s+$", "")
        
        test.assert_equals(address1, address2, "Same wallet should produce same address")
        test.assert_equals(address2, address3, "Same wallet should produce same address")
        
        -- Cleanup
        test.cleanup(wallet_file)
    end,
    
    ["Different wallets produce different addresses"] = function()
        -- Generate two wallets
        local wallet1_output = test.run_command("./hbwallet")
        local wallet2_output = test.run_command("./hbwallet")
        
        local wallet1_file = test.temp_file(wallet1_output)
        local wallet2_file = test.temp_file(wallet2_output)
        
        -- Extract addresses
        local address1 = test.run_command("./hbwallet public-key --file " .. wallet1_file):gsub("%s+$", "")
        local address2 = test.run_command("./hbwallet public-key --file " .. wallet2_file):gsub("%s+$", "")
        
        test.assert_true(address1 ~= address2, "Different wallets should have different addresses")
        
        -- Cleanup
        test.cleanup(wallet1_file)
        test.cleanup(wallet2_file)
    end,
    
    ["Address is deterministic based on public key"] = function()
        -- Generate wallet and extract components
        local wallet_output = test.run_command("./hbwallet")
        local jwk = json.decode(wallet_output)
        
        -- Create a public-only version
        local public_jwk = {
            kty = jwk.kty,
            n = jwk.n,
            e = jwk.e
        }
        
        -- Save both versions
        local full_wallet_file = test.temp_file(wallet_output)
        -- Manually construct JSON for public key only
        local public_json = string.format('{"kty":"%s","n":"%s","e":"%s"}', 
            public_jwk.kty, public_jwk.n, public_jwk.e)
        local public_wallet_file = test.temp_file(public_json)
        
        -- Extract addresses
        local full_address = test.run_command("./hbwallet public-key --file " .. full_wallet_file):gsub("%s+$", "")
        local public_address = test.run_command("./hbwallet public-key --file " .. public_wallet_file):gsub("%s+$", "")
        
        test.assert_equals(full_address, public_address, 
            "Address should be same whether derived from full or public-only JWK")
        
        -- Cleanup
        test.cleanup(full_wallet_file)
        test.cleanup(public_wallet_file)
    end,
    
    ["Error handling for missing file"] = function()
        local output, success = test.run_command("./hbwallet public-key --file nonexistent.json 2>&1")
        test.assert_false(success, "Command should fail for missing file")
        test.assert_matches(output, "Error:", "Should show error message")
        test.assert_matches(output, "Cannot open file", "Should mention file cannot be opened")
    end,
    
    ["Error handling for invalid JSON"] = function()
        local invalid_file = test.temp_file("{ invalid json }")
        local output, success = test.run_command("./hbwallet public-key --file " .. invalid_file .. " 2>&1")
        test.assert_false(success, "Command should fail for invalid JSON")
        test.assert_matches(output, "Error:", "Should show error message")
        -- The actual error mentions "Expected string key" for invalid JSON
        test.assert_matches(output, "Expected string key", "Should mention JSON parsing error")
        test.cleanup(invalid_file)
    end,
    
    ["Error handling for missing --file argument"] = function()
        local output, success = test.run_command("./hbwallet public-key 2>&1")
        test.assert_false(success, "Command should fail without --file")
        test.assert_matches(output, "Error:", "Should show error message")
        test.assert_matches(output, "--file", "Should mention --file requirement")
    end
})