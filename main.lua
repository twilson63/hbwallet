#!/usr/bin/env lua

-- hbwallet - A Lua binary that creates JWK files for Arweave
-- Built with Hype framework

local json = require("json")
local crypto = require("crypto")
local base64 = require("base64")

-- Parse command line arguments
local function parse_args(args)
    local cmd = args[1]
    local options = {}
    
    for i = 2, #args do
        if args[i] == "--file" or args[i] == "-f" then
            options.file = args[i + 1]
            i = i + 1
        end
    end
    
    return cmd, options
end

-- Generate RSA keypair in JWK format
local function generate_jwk()
    -- Generate RSA keypair (2048 bits)
    local keypair = crypto.generateKeyPair("RSA", {
        modulusLength = 2048,
        publicKeyEncoding = {
            type = "pkcs1",
            format = "pem"
        },
        privateKeyEncoding = {
            type = "pkcs1",
            format = "pem"
        }
    })
    
    -- Convert to JWK format
    local jwk = {
        kty = "RSA",
        n = base64.urlEncode(keypair.publicKey.n),
        e = base64.urlEncode(keypair.publicKey.e),
        d = base64.urlEncode(keypair.privateKey.d),
        p = base64.urlEncode(keypair.privateKey.p),
        q = base64.urlEncode(keypair.privateKey.q),
        dp = base64.urlEncode(keypair.privateKey.dp),
        dq = base64.urlEncode(keypair.privateKey.dq),
        qi = base64.urlEncode(keypair.privateKey.qi)
    }
    
    return jwk
end

-- Get public key hash (43 character Arweave address)
local function get_public_key_hash(jwk)
    -- Extract public key components
    local publicKey = {
        kty = jwk.kty,
        n = jwk.n,
        e = jwk.e
    }
    
    -- Create canonical JSON string
    local publicKeyJson = json.encode(publicKey, { sort_keys = true })
    
    -- Hash with SHA-256
    local hash = crypto.hash("sha256", publicKeyJson)
    
    -- Base64URL encode and truncate to 43 characters
    local address = base64.urlEncode(hash):sub(1, 43)
    
    return address
end

-- Read JWK from file
local function read_jwk_file(filename)
    local file = io.open(filename, "r")
    if not file then
        io.stderr:write("Error: Cannot open file " .. filename .. "\n")
        os.exit(1)
    end
    
    local content = file:read("*all")
    file:close()
    
    local ok, jwk = pcall(json.decode, content)
    if not ok then
        io.stderr:write("Error: Invalid JSON in file " .. filename .. "\n")
        os.exit(1)
    end
    
    return jwk
end

-- Main function
local function main(args)
    local cmd, options = parse_args(args)
    
    if cmd == "public-key" then
        -- Get public key hash from wallet file
        if not options.file then
            io.stderr:write("Error: --file option required for public-key command\n")
            os.exit(1)
        end
        
        local jwk = read_jwk_file(options.file)
        local address = get_public_key_hash(jwk)
        print(address)
        
    else
        -- Generate new wallet
        local jwk = generate_jwk()
        print(json.encode(jwk, { indent = 2 }))
    end
end

-- Run main function
main(arg or {})