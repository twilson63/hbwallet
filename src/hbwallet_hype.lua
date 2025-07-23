#!/usr/bin/env hype

-- hbwallet - Arweave JWK wallet generator using Hype crypto
-- Zero external dependencies - uses only Hype framework built-ins

local crypto = require("crypto")
local json = require("json")
local httpsig = require("httpsig")

-- Base64URL encoding/decoding functions
local function base64url_encode(data)
    -- Hype's crypto module likely handles base64url internally
    -- but we need this for manual encoding if needed
    local b64 = require("base64").encode(data)
    return b64:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

local function base64url_decode(str)
    -- Replace URL-safe chars back
    str = str:gsub("-", "+"):gsub("_", "/")
    -- Add padding
    local padding = (4 - #str % 4) % 4
    str = str .. string.rep("=", padding)
    return require("base64").decode(str)
end

-- Generate RSA JWK using Hype's crypto
local function generate_jwk()
    -- Arweave uses 4096-bit RSA keys
    -- Using RS256 which should generate appropriate RSA keys
    local jwk = crypto.generate_jwk("RS256")
    
    -- The generated JWK should already have all required fields:
    -- kty, n, e, d, p, q, dp, dq, qi
    
    return jwk
end

-- Get wallet address from JWK
local function get_wallet_address(jwk)
    -- Validate JWK structure
    if not jwk or type(jwk) ~= "table" then
        error("Invalid JWK: not a table")
    end
    if not jwk.n or type(jwk.n) ~= "string" then
        error("Invalid JWK: missing or invalid 'n' field")
    end
    
    -- For Arweave addresses, we need to:
    -- 1. Decode the base64url encoded modulus 'n'
    -- 2. SHA256 hash the raw binary value
    -- 3. Base64URL encode the hash
    
    -- Decode the raw binary value of n
    local n_binary = base64url_decode(jwk.n)
    
    -- Use Hype's httpsig module for SHA256
    local hash = httpsig.create_digest(n_binary, "sha256")
    
    -- The digest is already base64 encoded, but we need base64url
    -- Remove the "SHA-256=" prefix if present
    local hash_b64 = hash:gsub("^SHA%-256=", "")
    
    -- Convert to base64url
    local address = hash_b64:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
    
    return address
end


-- Read file
local function read_file(filename)
    -- Basic path validation
    if filename:match("%.%.") then
        error("Invalid file path: contains '..'")
    end
    
    local file = io.open(filename, "r")
    if not file then
        io.stderr:write("Error: Cannot open file " .. filename .. "\n")
        os.exit(1)
    end
    
    -- Limit file size to prevent DoS
    local size = file:seek("end")
    if size > 1024 * 1024 then  -- 1MB limit
        file:close()
        error("File too large: " .. size .. " bytes")
    end
    file:seek("set")
    
    local content = file:read("*all")
    file:close()
    return content
end

-- Parse arguments
local function parse_args(args)
    if #args == 0 then
        return nil, {}
    end
    
    local cmd = args[1]
    local options = {}
    
    local i = 2
    while i <= #args do
        if args[i] == "--file" or args[i] == "-f" then
            if i + 1 <= #args then
                options.file = args[i + 1]
                i = i + 1
            else
                io.stderr:write("Error: --file requires a filename\n")
                os.exit(1)
            end
        end
        i = i + 1
    end
    
    return cmd, options
end

-- Main function
local function main(args)
    local cmd, options = parse_args(args)
    
    if cmd == "public-key" then
        if not options.file then
            io.stderr:write("Error: --file option required for public-key command\n")
            io.stderr:write("Usage: hbwallet public-key --file <wallet.json>\n")
            os.exit(1)
        end
        
        local content = read_file(options.file)
        local ok, jwk = pcall(json.decode, content)
        if not ok then
            io.stderr:write("Error: Invalid JSON in file " .. options.file .. "\n")
            os.exit(1)
        end
        
        -- Get wallet address
        local address = get_wallet_address(jwk)
        print(address)
        
    elseif cmd == nil then
        -- Generate new wallet
        local jwk = generate_jwk()
        
        -- Output JSON
        print(json.encode(jwk))
        
        io.stderr:write("\nWARNING: This file contains your private key. Keep it secure!\n")
        io.stderr:write("Recommended: chmod 600 <filename>\n")
        
    else
        io.stderr:write("Error: Unknown command '" .. cmd .. "'\n")
        io.stderr:write("Usage:\n")
        io.stderr:write("  hbwallet                              # Generate new wallet\n")
        io.stderr:write("  hbwallet public-key --file <wallet>   # Get wallet address\n")
        os.exit(1)
    end
end

-- Run
main(arg or {})