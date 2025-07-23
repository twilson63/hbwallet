-- Tests for JWK generation and validation

local test = require("test.test_framework")
local json = require("json")

-- Test JWK generation
test.suite("JWK Generation", {
    ["Generate wallet creates valid JWK"] = function()
        -- Run hbwallet to generate a new wallet
        local output, success = test.run_command("./hbwallet")
        test.assert_true(success, "hbwallet command should succeed")
        
        -- Parse JSON output
        local ok, jwk = pcall(json.decode, output)
        test.assert_true(ok, "Output should be valid JSON")
        
        -- Verify JWK structure
        test.assert_equals(jwk.kty, "RSA", "Key type should be RSA")
        test.assert_not_nil(jwk.n, "Modulus (n) should exist")
        test.assert_not_nil(jwk.e, "Public exponent (e) should exist")
        test.assert_not_nil(jwk.d, "Private exponent (d) should exist")
        test.assert_not_nil(jwk.p, "Prime 1 (p) should exist")
        test.assert_not_nil(jwk.q, "Prime 2 (q) should exist")
        test.assert_not_nil(jwk.dp, "Exponent 1 (dp) should exist")
        test.assert_not_nil(jwk.dq, "Exponent 2 (dq) should exist")
        test.assert_not_nil(jwk.qi, "Coefficient (qi) should exist")
    end,
    
    ["JWK components are base64url encoded"] = function()
        local output = test.run_command("./hbwallet")
        local jwk = json.decode(output)
        
        -- Check that all components are base64url encoded (no padding, no +/)
        local components = {"n", "e", "d", "p", "q", "dp", "dq", "qi"}
        for _, comp in ipairs(components) do
            test.assert_false(string.find(jwk[comp], "="), comp .. " should not have padding")
            test.assert_false(string.find(jwk[comp], "+"), comp .. " should not have +")
            test.assert_false(string.find(jwk[comp], "/"), comp .. " should not have /")
            test.assert_matches(jwk[comp], "^[A-Za-z0-9_-]+$", comp .. " should be base64url")
        end
    end,
    
    ["Public exponent is standard value"] = function()
        local output = test.run_command("./hbwallet")
        local jwk = json.decode(output)
        
        -- Standard RSA public exponent is 65537, which is "AQAB" in base64url
        test.assert_equals(jwk.e, "AQAB", "Public exponent should be standard 65537")
    end,
    
    ["Modulus has correct length for 2048-bit key"] = function()
        local output = test.run_command("./hbwallet")
        local jwk = json.decode(output)
        
        -- For a 2048-bit RSA key, the modulus should be about 342-344 chars in base64
        local n_length = #jwk.n
        test.assert_true(n_length >= 340 and n_length <= 345, 
            "Modulus length should be appropriate for 2048-bit key")
    end,
    
    ["Multiple generations create different keys"] = function()
        -- Generate two wallets
        local output1 = test.run_command("./hbwallet")
        local output2 = test.run_command("./hbwallet")
        
        local jwk1 = json.decode(output1)
        local jwk2 = json.decode(output2)
        
        -- Keys should be different
        test.assert_true(jwk1.n ~= jwk2.n, "Modulus should be different")
        test.assert_true(jwk1.d ~= jwk2.d, "Private exponent should be different")
        test.assert_true(jwk1.p ~= jwk2.p, "Prime p should be different")
        test.assert_true(jwk1.q ~= jwk2.q, "Prime q should be different")
    end,
    
    ["Generated JWK can be saved to file"] = function()
        -- Generate wallet and save to file
        local output = test.run_command("./hbwallet > test_wallet.json")
        
        -- Read the file
        local content = test.read_file("test_wallet.json")
        test.assert_not_nil(content, "Wallet file should be created")
        
        -- Parse and validate
        local ok, jwk = pcall(json.decode, content)
        test.assert_true(ok, "Saved file should contain valid JSON")
        test.assert_equals(jwk.kty, "RSA", "Saved JWK should be RSA type")
        
        -- Cleanup
        test.cleanup("test_wallet.json")
    end
})