-- JWK RSA key generation module for Arweave
local ffi = require("ffi")
local bit = require("bit")

-- Base64URL encoding (no padding)
local function base64url_encode(data)
    local b64 = require("mime").b64(data)
    return b64:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

-- Generate random bytes
local function random_bytes(n)
    local bytes = {}
    for i = 1, n do
        bytes[i] = string.char(math.random(0, 255))
    end
    return table.concat(bytes)
end

-- Convert number to big-endian bytes
local function num_to_bytes(num, len)
    local bytes = {}
    for i = len, 1, -1 do
        bytes[i] = string.char(bit.band(num, 0xFF))
        num = bit.rshift(num, 8)
    end
    return table.concat(bytes)
end

-- Simple RSA key generation (for demonstration - use OpenSSL in production)
local function generate_rsa_keypair()
    -- For a proper implementation, we'll use OpenSSL via FFI
    -- This is a placeholder that would need proper crypto library integration
    
    -- Standard RSA public exponent
    local e = 65537
    
    -- Generate random modulus n (simplified - real RSA needs proper prime generation)
    -- In production, use proper crypto library
    local n_bytes = random_bytes(512) -- 4096 bits
    
    -- For demonstration, create a valid JWK structure
    -- Real implementation would use OpenSSL or similar
    return {
        n = base64url_encode(n_bytes),
        e = base64url_encode(num_to_bytes(e, 3)),
        d = base64url_encode(random_bytes(512)),  -- 4096 bits
        p = base64url_encode(random_bytes(256)),  -- 2048 bits
        q = base64url_encode(random_bytes(256)),  -- 2048 bits
        dp = base64url_encode(random_bytes(256)), -- 2048 bits
        dq = base64url_encode(random_bytes(256)), -- 2048 bits
        qi = base64url_encode(random_bytes(256))  -- 2048 bits
    }
end

-- Generate JWK
local function generate_jwk()
    local keypair = generate_rsa_keypair()
    
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
end

return {
    generate = generate_jwk,
    base64url_encode = base64url_encode
}