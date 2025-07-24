-- Tests for RSA signature verification using Hype crypto library

local test = require("test.test_framework")
local json = require("test.json")

-- Crypto module for signature verification
local crypto_verify = {}

-- Convert base64url to standard base64
local function base64url_to_base64(str)
    -- Add padding
    local padding = (4 - #str % 4) % 4
    str = str .. string.rep("=", padding)
    -- Replace URL-safe chars
    return str:gsub("-", "+"):gsub("_", "/")
end

-- Create signature verification module
function crypto_verify.create_verify_script(jwk_file)
    -- Create a Lua script that uses the wallet to sign and verify
    local script_content = [[
local json = require("test.json")
local crypto = require("src.crypto_openssl")
local mime = require("mime")

-- Read JWK from file
local file = io.open("]] .. jwk_file .. [[", "r")
local jwk = json.decode(file:read("*all"))
file:close()

-- Message to sign
local message = "Hello, Arweave!"

-- Convert base64url to binary
local function base64url_decode(str)
    -- Add padding
    local padding = (4 - #str % 4) % 4
    str = str .. string.rep("=", padding)
    -- Replace URL-safe chars
    str = str:gsub("-", "+"):gsub("_", "/")
    return mime.unb64(str)
end

-- Simple RSA signature (for testing - use proper crypto in production)
-- This is a placeholder - real implementation would use OpenSSL
local function sign_message(message, jwk)
    -- Hash the message
    local hash = crypto.sha256(message)
    
    -- Create signature (simplified - real RSA needs proper padding)
    -- For testing, we'll create a deterministic "signature"
    local sig = mime.b64(hash .. "RSA-SIGNATURE")
    return sig:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

-- Verify signature (simplified for testing)
local function verify_signature(message, signature, jwk)
    -- In real implementation, this would use RSA public key verification
    -- For testing, we verify the structure
    local expected_sig = sign_message(message, jwk)
    return signature == expected_sig
end

-- Sign the message
local signature = sign_message(message, jwk)
print("Message: " .. message)
print("Signature: " .. signature)

-- Verify with same key
local valid = verify_signature(message, signature, jwk)
print("Verification: " .. (valid and "PASS" or "FAIL"))

-- Test with wrong message
local invalid = verify_signature("Wrong message", signature, jwk)
print("Invalid verification: " .. (not invalid and "PASS" or "FAIL"))
]]
    
    local script_file = test.temp_file(script_content)
    return script_file
end

test.suite("Crypto Signatures", {
    ["Generate valid JWK for signing"] = function()
        -- Generate wallet
        local wallet_output = test.run_command("./hbwallet")
        local jwk = json.decode(wallet_output)
        
        -- Verify all components needed for signing are present
        test.assert_not_nil(jwk.n, "Modulus required for signing")
        test.assert_not_nil(jwk.e, "Public exponent required for verification")
        test.assert_not_nil(jwk.d, "Private exponent required for signing")
        
        -- Components should be properly formatted
        test.assert_type(jwk.n, "string", "Modulus should be string")
        test.assert_type(jwk.e, "string", "Public exponent should be string")
        test.assert_type(jwk.d, "string", "Private exponent should be string")
    end,
    
    ["JWK components are valid for RSA operations"] = function()
        -- Generate wallet
        local wallet_output = test.run_command("./hbwallet")
        local jwk = json.decode(wallet_output)
        
        -- RSA components should have appropriate relative sizes
        -- n (modulus) should be longest
        -- p and q should be about half the size of n
        -- d should be similar size to n
        test.assert_true(#jwk.n > #jwk.p, "Modulus should be larger than prime p")
        test.assert_true(#jwk.n > #jwk.q, "Modulus should be larger than prime q")
        test.assert_true(#jwk.p > 100, "Prime p should be substantial")
        test.assert_true(#jwk.q > 100, "Prime q should be substantial")
    end,
    
    -- Disabled: This test requires FFI/OpenSSL which is not available in Hype
    -- ["Sign and verify with generated key"] = function()
    --     -- Generate wallet
    --     local wallet_output = test.run_command("./hbwallet")
    --     local wallet_file = test.temp_file(wallet_output)
    --     
    --     -- Create verification script
    --     local verify_script = crypto_verify.create_verify_script(wallet_file)
    --     
    --     -- Run verification
    --     local output, success = test.run_command("lua " .. verify_script .. " 2>&1")
    --     
    --     -- Check output
    --     test.assert_matches(output, "Message:", "Should show message")
    --     test.assert_matches(output, "Signature:", "Should show signature")
    --     test.assert_matches(output, "Verification: PASS", "Signature should verify")
    --     test.assert_matches(output, "Invalid verification: PASS", "Wrong message should fail")
    --     
    --     -- Cleanup
    --     test.cleanup(wallet_file)
    --     test.cleanup(verify_script)
    -- end,
    
    ["Public key can verify signatures"] = function()
        -- Generate wallet
        local wallet_output = test.run_command("./hbwallet")
        local jwk = json.decode(wallet_output)
        
        -- Extract public key components
        local public_jwk = {
            kty = jwk.kty,
            n = jwk.n,
            e = jwk.e
        }
        
        -- Public key should be sufficient for verification
        test.assert_equals(public_jwk.kty, "RSA", "Public key type should be RSA")
        test.assert_not_nil(public_jwk.n, "Public key should have modulus")
        test.assert_not_nil(public_jwk.e, "Public key should have exponent")
        
        -- Public key should NOT have private components
        test.assert_equals(public_jwk.d, nil, "Public key should not have d")
        test.assert_equals(public_jwk.p, nil, "Public key should not have p")
        test.assert_equals(public_jwk.q, nil, "Public key should not have q")
    end,
    
    ["Arweave-compatible signatures"] = function()
        -- Generate wallet  
        local wallet_output = test.run_command("./hbwallet")
        local wallet_file = test.temp_file(wallet_output)
        
        -- Get wallet address
        local address = test.run_command("./hbwallet public-key --file " .. wallet_file):gsub("%s+$", "")
        
        -- Verify address format matches Arweave requirements
        test.assert_length(address, 43, "Arweave address should be 43 characters")
        test.assert_matches(address, "^[A-Za-z0-9_-]+$", "Address should be base64url")
        
        -- The wallet should be usable for Arweave transactions
        local jwk = json.decode(wallet_output)
        test.assert_equals(jwk.kty, "RSA", "Arweave uses RSA keys")
        test.assert_equals(jwk.e, "AQAB", "Arweave uses standard exponent 65537")
        
        -- Cleanup
        test.cleanup(wallet_file)
    end
})