-- Secure SHA256 implementation for hbwallet
-- This implementation avoids command injection vulnerabilities

local sha256 = {}

-- Try to use LuaCrypto if available
local ok, crypto = pcall(require, "crypto")
if ok and crypto.digest then
    function sha256.hash(data)
        return crypto.digest("sha256", data, true) -- true for raw binary output
    end
    sha256.available = "luacrypto"
    return sha256
end

-- Try to use OpenSSL via FFI if available
local ok, ffi = pcall(require, "ffi")
if ok then
    local ok_ssl = pcall(function()
        ffi.cdef[[
            typedef struct engine_st ENGINE;
            typedef struct evp_md_st EVP_MD;
            typedef struct evp_md_ctx_st EVP_MD_CTX;
            
            const EVP_MD *EVP_sha256(void);
            EVP_MD_CTX *EVP_MD_CTX_new(void);
            void EVP_MD_CTX_free(EVP_MD_CTX *ctx);
            int EVP_DigestInit_ex(EVP_MD_CTX *ctx, const EVP_MD *type, ENGINE *impl);
            int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *d, size_t cnt);
            int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md, unsigned int *s);
        ]]
        
        local ssl = ffi.load("ssl")
        
        function sha256.hash(data)
            local ctx = ssl.EVP_MD_CTX_new()
            if ctx == nil then
                error("Failed to create digest context")
            end
            
            local md = ssl.EVP_sha256()
            if ssl.EVP_DigestInit_ex(ctx, md, nil) ~= 1 then
                ssl.EVP_MD_CTX_free(ctx)
                error("Failed to initialize digest")
            end
            
            if ssl.EVP_DigestUpdate(ctx, data, #data) ~= 1 then
                ssl.EVP_MD_CTX_free(ctx)
                error("Failed to update digest")
            end
            
            local hash = ffi.new("unsigned char[32]")
            local hash_len = ffi.new("unsigned int[1]")
            
            if ssl.EVP_DigestFinal_ex(ctx, hash, hash_len) ~= 1 then
                ssl.EVP_MD_CTX_free(ctx)
                error("Failed to finalize digest")
            end
            
            ssl.EVP_MD_CTX_free(ctx)
            
            return ffi.string(hash, hash_len[0])
        end
        
        sha256.available = "openssl-ffi"
        return sha256
    end)
    
    if ok_ssl then
        return sha256
    end
end

-- Fallback: Use /dev/urandom for hash (NOT cryptographically correct, but better than command injection)
-- This should only be used as a last resort
local function read_dev_urandom(len)
    local f = io.open("/dev/urandom", "rb")
    if not f then
        error("Cannot open /dev/urandom")
    end
    local data = f:read(len)
    f:close()
    if not data or #data ~= len then
        error("Failed to read from /dev/urandom")
    end
    return data
end

-- Pure Lua SHA256 implementation (simplified, for fallback only)
-- Based on FIPS 180-4
local function sha256_pure_lua(msg)
    -- SHA256 constants
    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }
    
    -- Initial hash values
    local H = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }
    
    -- Helper functions
    local function rrotate(x, n)
        return ((x >> n) | (x << (32 - n))) & 0xffffffff
    end
    
    local function ch(x, y, z)
        return (x & y) ~ ((~x) & z)
    end
    
    local function maj(x, y, z)
        return (x & y) ~ (x & z) ~ (y & z)
    end
    
    local function sigma0(x)
        return rrotate(x, 2) ~ rrotate(x, 13) ~ rrotate(x, 22)
    end
    
    local function sigma1(x)
        return rrotate(x, 6) ~ rrotate(x, 11) ~ rrotate(x, 25)
    end
    
    local function gamma0(x)
        return rrotate(x, 7) ~ rrotate(x, 18) ~ (x >> 3)
    end
    
    local function gamma1(x)
        return rrotate(x, 17) ~ rrotate(x, 19) ~ (x >> 10)
    end
    
    -- Preprocessing
    local msglen = #msg
    local padlen = (55 - msglen) % 64
    local padded = msg .. "\x80" .. string.rep("\0", padlen) .. string.pack(">I8", msglen * 8)
    
    -- Process message in 512-bit chunks
    for i = 1, #padded, 64 do
        local chunk = padded:sub(i, i + 63)
        local w = {}
        
        -- Break chunk into sixteen 32-bit words
        for j = 1, 16 do
            w[j] = string.unpack(">I4", chunk, (j - 1) * 4 + 1)
        end
        
        -- Extend the sixteen 32-bit words into sixty-four 32-bit words
        for j = 17, 64 do
            w[j] = (gamma1(w[j - 2]) + w[j - 7] + gamma0(w[j - 15]) + w[j - 16]) & 0xffffffff
        end
        
        -- Initialize working variables
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        
        -- Main loop
        for j = 1, 64 do
            local t1 = (h + sigma1(e) + ch(e, f, g) + K[j] + w[j]) & 0xffffffff
            local t2 = (sigma0(a) + maj(a, b, c)) & 0xffffffff
            h = g
            g = f
            f = e
            e = (d + t1) & 0xffffffff
            d = c
            c = b
            b = a
            a = (t1 + t2) & 0xffffffff
        end
        
        -- Add compressed chunk to current hash value
        H[1] = (H[1] + a) & 0xffffffff
        H[2] = (H[2] + b) & 0xffffffff
        H[3] = (H[3] + c) & 0xffffffff
        H[4] = (H[4] + d) & 0xffffffff
        H[5] = (H[5] + e) & 0xffffffff
        H[6] = (H[6] + f) & 0xffffffff
        H[7] = (H[7] + g) & 0xffffffff
        H[8] = (H[8] + h) & 0xffffffff
    end
    
    -- Produce final hash value
    local hash = ""
    for i = 1, 8 do
        hash = hash .. string.pack(">I4", H[i])
    end
    
    return hash
end

-- Check if we have bitwise operators (Lua 5.3+)
local has_bitops = pcall(function() return 1 ~ 1 end)

if has_bitops then
    sha256.hash = sha256_pure_lua
    sha256.available = "pure-lua"
else
    -- Last resort: error out rather than using insecure method
    function sha256.hash(data)
        error("No secure SHA256 implementation available. Please install LuaCrypto or use Lua 5.3+")
    end
    sha256.available = "none"
end

return sha256