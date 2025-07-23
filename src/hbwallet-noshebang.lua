-- hbwallet - Arweave JWK wallet generator
-- Using Hype framework

local json = require("json")

-- Try to use OpenSSL crypto, fallback to pure Lua
local crypto_impl
local ok = pcall(function() 
    crypto_impl = require("src.crypto_openssl")
end)
if not ok then
    crypto_impl = require("src.jwk")
end

-- Base64URL encoding
local function base64url_encode(data)
    local b64 = require("mime").b64(data)
    return b64:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

-- SHA256 hash function
local function sha256(data)
    if crypto_impl.sha256 then
        return crypto_impl.sha256(data)
    else
        -- Fallback to pure Lua SHA256
        local sha2 = require("sha2")
        return sha2.sha256(data)
    end
end

-- Generate Arweave wallet address from JWK
local function get_wallet_address(jwk)
    -- Create public key object with only public components
    local public_key = {
        e = jwk.e,
        kty = jwk.kty,
        n = jwk.n
    }
    
    -- Sort keys for canonical JSON
    local sorted_json = json.encode(public_key, { sort_keys = true })
    
    -- Hash the public key
    local hash = sha256(sorted_json)
    
    -- Base64URL encode and return first 43 characters
    local address = base64url_encode(hash)
    return address:sub(1, 43)
end

-- Generate new JWK wallet
local function generate_wallet()
    if crypto_impl.generate_rsa_keypair then
        -- Use OpenSSL implementation
        local keypair = crypto_impl.generate_rsa_keypair(4096)
        return {
            kty = "RSA",
            n = keypair.n,
            e = keypair.e,
            d = keypair.d,
            p = keypair.p,
            q = keypair.q,
            dp = keypair.dp,
            dq = keypair.dq,
            qi = keypair.qi
        }
    else
        -- Use fallback implementation
        return crypto_impl.generate()
    end
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

-- Parse command line arguments
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
        -- Get wallet address from JWK file
        if not options.file then
            io.stderr:write("Error: --file option required for public-key command\n")
            io.stderr:write("Usage: hbwallet public-key --file <wallet.json>\n")
            os.exit(1)
        end
        
        local jwk = read_jwk_file(options.file)
        local address = get_wallet_address(jwk)
        print(address)
        
    elseif cmd == nil then
        -- Generate new wallet and output to stdout
        local jwk = generate_wallet()
        print(json.encode(jwk, { indent = 2 }))
        
    else
        io.stderr:write("Error: Unknown command '" .. cmd .. "'\n")
        io.stderr:write("Usage:\n")
        io.stderr:write("  hbwallet                              # Generate new wallet\n")
        io.stderr:write("  hbwallet public-key --file <wallet>   # Get wallet address\n")
        os.exit(1)
    end
end

-- Run if executed directly
if arg then
    main(arg)
end

return {
    generate_wallet = generate_wallet,
    get_wallet_address = get_wallet_address
}