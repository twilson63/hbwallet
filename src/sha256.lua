-- Pure Lua SHA256 implementation
-- Compatible with Lua 5.1+

local sha256 = {}

-- 32-bit bitwise operations for Lua 5.1/5.2 compatibility
local bit32 = bit32 or bit or {}

if not bit32.band then
    -- Implement basic bitwise operations if not available
    function bit32.band(a, b)
        local result = 0
        local bitval = 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end
    
    function bit32.bor(a, b)
        local result = 0
        local bitval = 1
        while a > 0 or b > 0 do
            if a % 2 == 1 or b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end
    
    function bit32.bxor(a, b)
        local result = 0
        local bitval = 1
        while a > 0 or b > 0 do
            if (a % 2 + b % 2) == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end
    
    function bit32.bnot(a)
        return 4294967295 - a
    end
    
    function bit32.rshift(a, n)
        return math.floor(a / (2 ^ n))
    end
    
    function bit32.lshift(a, n)
        return (a * (2 ^ n)) % 4294967296
    end
end

-- Ensure 32-bit
local function u32(n)
    return n % 4294967296
end

-- Right rotate
local function rrotate(n, b)
    n = u32(n)
    return u32(bit32.bor(bit32.rshift(n, b), bit32.lshift(n, 32 - b)))
end

-- SHA256 constants
local k = {
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

function sha256.hash(msg)
    -- Initial hash values
    local h = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }
    
    -- Preprocessing
    local len = #msg
    local msg_len_bits = len * 8
    
    -- Append bit '1' to message
    msg = msg .. string.char(0x80)
    
    -- Append zero bits
    while (#msg % 64) ~= 56 do
        msg = msg .. string.char(0)
    end
    
    -- Append length in bits as 64-bit big-endian
    for i = 56, 0, -8 do
        msg = msg .. string.char(bit32.band(bit32.rshift(msg_len_bits, i), 0xff))
    end
    
    -- Process message in 512-bit chunks
    for chunk_start = 1, #msg, 64 do
        local w = {}
        
        -- Copy chunk into first 16 words w[0..15] of the message schedule
        for i = 1, 16 do
            local b1, b2, b3, b4 = msg:byte(chunk_start + (i-1)*4, chunk_start + i*4 - 1)
            w[i] = u32(bit32.bor(
                bit32.lshift(b1, 24),
                bit32.lshift(b2, 16),
                bit32.lshift(b3, 8),
                b4
            ))
        end
        
        -- Extend the first 16 words into the remaining 48 words w[16..63]
        for i = 17, 64 do
            local s0 = bit32.bxor(
                rrotate(w[i-15], 7),
                rrotate(w[i-15], 18),
                bit32.rshift(w[i-15], 3)
            )
            local s1 = bit32.bxor(
                rrotate(w[i-2], 17),
                rrotate(w[i-2], 19),
                bit32.rshift(w[i-2], 10)
            )
            w[i] = u32(w[i-16] + s0 + w[i-7] + s1)
        end
        
        -- Initialize working variables
        local a, b, c, d, e, f, g, h_var = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        
        -- Main loop
        for i = 1, 64 do
            local s1 = bit32.bxor(
                rrotate(e, 6),
                rrotate(e, 11),
                rrotate(e, 25)
            )
            local ch = bit32.bxor(
                bit32.band(e, f),
                bit32.band(bit32.bnot(e), g)
            )
            local temp1 = u32(h_var + s1 + ch + k[i] + w[i])
            local s0 = bit32.bxor(
                rrotate(a, 2),
                rrotate(a, 13),
                rrotate(a, 22)
            )
            local maj = bit32.bxor(
                bit32.band(a, b),
                bit32.band(a, c),
                bit32.band(b, c)
            )
            local temp2 = u32(s0 + maj)
            
            h_var = g
            g = f
            f = e
            e = u32(d + temp1)
            d = c
            c = b
            b = a
            a = u32(temp1 + temp2)
        end
        
        -- Add compressed chunk to current hash value
        h[1] = u32(h[1] + a)
        h[2] = u32(h[2] + b)
        h[3] = u32(h[3] + c)
        h[4] = u32(h[4] + d)
        h[5] = u32(h[5] + e)
        h[6] = u32(h[6] + f)
        h[7] = u32(h[7] + g)
        h[8] = u32(h[8] + h_var)
    end
    
    -- Produce final hash value
    local result = ""
    for i = 1, 8 do
        for j = 24, 0, -8 do
            result = result .. string.char(bit32.band(bit32.rshift(h[i], j), 0xff))
        end
    end
    
    return result
end

return sha256