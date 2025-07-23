#!/usr/bin/env lua

-- hbwallet - Secure implementation
-- Generates cryptographically secure Arweave JWK wallets

-- JSON module (unchanged, it's safe)
local json = {}
local escape_char_map = {
    ["\\"] = "\\\\", ["\""] = "\\\"", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"
}

local function escape_char(c)
    return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

function json.encode(val, options)
    options = options or {}
    local indent = options.indent
    
    local function encode_string(s)
        return '"' .. s:gsub('[%z\1-\31\\"]', escape_char) .. '"'
    end
    
    local function encode_value(v, depth)
        depth = depth or 0
        local t = type(v)
        
        if t == "nil" then
            return "null"
        elseif t == "boolean" then
            return tostring(v)
        elseif t == "number" then
            return tostring(v)
        elseif t == "string" then
            return encode_string(v)
        elseif t == "table" then
            local parts = {}
            local is_array = #v > 0
            
            if is_array then
                for i = 1, #v do
                    parts[i] = encode_value(v[i], depth + 1)
                end
                if indent then
                    local spacing = string.rep(" ", depth * indent)
                    local inner_spacing = string.rep(" ", (depth + 1) * indent)
                    return "[\n" .. inner_spacing .. table.concat(parts, ",\n" .. inner_spacing) .. "\n" .. spacing .. "]"
                else
                    return "[" .. table.concat(parts, ",") .. "]"
                end
            else
                local keys = {}
                for k in pairs(v) do
                    if type(k) == "string" then
                        table.insert(keys, k)
                    end
                end
                if options.sort_keys then
                    table.sort(keys)
                end
                
                for _, k in ipairs(keys) do
                    local key = encode_string(k)
                    local value = encode_value(v[k], depth + 1)
                    table.insert(parts, key .. ":" .. (indent and " " or "") .. value)
                end
                
                if indent then
                    local spacing = string.rep(" ", depth * indent)
                    local inner_spacing = string.rep(" ", (depth + 1) * indent)
                    return "{\n" .. inner_spacing .. table.concat(parts, ",\n" .. inner_spacing) .. "\n" .. spacing .. "}"
                else
                    return "{" .. table.concat(parts, ",") .. "}"
                end
            end
        end
    end
    
    return encode_value(val)
end

function json.decode(str)
    local pos = 1
    
    local function skip_whitespace()
        while pos <= #str and str:match("^%s", pos) do
            pos = pos + 1
        end
    end
    
    local function decode_value()
        skip_whitespace()
        local c = str:sub(pos, pos)
        
        if c == '"' then
            pos = pos + 1
            local start = pos
            while pos <= #str do
                if str:sub(pos, pos) == '"' and str:sub(pos-1, pos-1) ~= '\\' then
                    local val = str:sub(start, pos-1)
                    pos = pos + 1
                    return val
                end
                pos = pos + 1
            end
            error("Unterminated string")
        elseif c == '{' then
            pos = pos + 1
            local obj = {}
            skip_whitespace()
            
            if str:sub(pos, pos) == '}' then
                pos = pos + 1
                return obj
            end
            
            while true do
                skip_whitespace()
                if str:sub(pos, pos) ~= '"' then
                    error("Expected string key")
                end
                
                local key = decode_value()
                skip_whitespace()
                
                if str:sub(pos, pos) ~= ':' then
                    error("Expected ':'")
                end
                pos = pos + 1
                
                obj[key] = decode_value()
                skip_whitespace()
                
                local c = str:sub(pos, pos)
                if c == '}' then
                    pos = pos + 1
                    return obj
                elseif c == ',' then
                    pos = pos + 1
                else
                    error("Expected ',' or '}'")
                end
            end
        elseif c:match("[%-0-9]") then
            local start = pos
            if c == '-' then pos = pos + 1 end
            while pos <= #str and str:sub(pos, pos):match("[0-9.]") do
                pos = pos + 1
            end
            return tonumber(str:sub(start, pos-1))
        elseif str:sub(pos, pos+3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos, pos+4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos, pos+3) == "null" then
            pos = pos + 4
            return nil
        end
    end
    
    return decode_value()
end

-- Secure Base64 encoding/decoding
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64_encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64url_encode(data)
    local b64 = base64_encode(data)
    return b64:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

local function base64url_decode(str)
    local b64lookup = {}
    for i = 1, 64 do
        b64lookup[b64chars:sub(i,i)] = i - 1
    end
    
    -- Replace URL-safe chars back
    str = str:gsub("-", "+"):gsub("_", "/")
    -- Add padding
    local padding = (4 - #str % 4) % 4
    str = str .. string.rep("=", padding)
    
    -- Decode base64
    local result = {}
    local bitval, bits = 0, 0
    
    for c in str:gmatch(".") do
        if c ~= "=" then
            local val = b64lookup[c]
            if val then
                bitval = bitval * 64 + val
                bits = bits + 6
                
                while bits >= 8 do
                    bits = bits - 8
                    local byte = math.floor(bitval / (2 ^ bits))
                    bitval = bitval % (2 ^ bits)
                    table.insert(result, string.char(byte))
                end
            end
        end
    end
    
    return table.concat(result)
end

-- Load secure implementations
local sha256_secure = require("sha256_secure")
local random_secure = require("random_secure")

-- Try to load OpenSSL crypto for proper RSA generation
local has_openssl = false
local crypto_openssl = nil
local ok = pcall(function()
    crypto_openssl = require("crypto_openssl")
    has_openssl = true
end)

-- Generate secure random bytes
local function random_bytes(n)
    return random_secure.bytes(n)
end

-- Compute SHA256 hash
local function sha256(data)
    return sha256_secure.hash(data)
end

-- Generate RSA JWK using OpenSSL if available
local function generate_jwk()
    if has_openssl and crypto_openssl.generate_rsa_keypair then
        -- Use proper RSA key generation
        local keypair = crypto_openssl.generate_rsa_keypair(4096)
        return {
            kty = "RSA",
            n = keypair.n,
            e = keypair.e or "AQAB",  -- Standard exponent 65537
            d = keypair.d,
            p = keypair.p,
            q = keypair.q,
            dp = keypair.dp,
            dq = keypair.dq,
            qi = keypair.qi
        }
    else
        -- Try using openssl command line as fallback
        local ok, jwk = pcall(function()
            -- Generate RSA key using openssl command
            local tmpkey = os.tmpname()
            local ret = os.execute("openssl genrsa -out " .. tmpkey .. " 4096 2>/dev/null")
            if ret ~= 0 then
                error("OpenSSL command failed")
            end
            
            -- Extract key components
            local function exec_openssl(cmd)
                local handle = io.popen("openssl " .. cmd .. " 2>/dev/null")
                local result = handle:read("*a")
                handle:close()
                return result
            end
            
            -- Get modulus
            local n_hex = exec_openssl("rsa -in " .. tmpkey .. " -modulus -noout"):match("Modulus=([0-9A-F]+)")
            if not n_hex then error("Failed to extract modulus") end
            
            -- Convert hex to binary
            local n_bin = n_hex:gsub("%x%x", function(hex)
                return string.char(tonumber(hex, 16))
            end)
            
            -- Get private key components in DER format and parse
            -- This is complex, so for now we'll generate a random JWK
            -- In production, use a proper crypto library
            
            os.remove(tmpkey)
            
            -- IMPORTANT: This is still not ideal - we should parse the full key
            -- For now, error out to force proper implementation
            error("Full OpenSSL key parsing not implemented. Please use LuaCrypto or OpenSSL FFI.")
        end)
        
        if not ok then
            -- No secure method available
            error("Cannot generate secure RSA keys. Please install LuaCrypto or ensure OpenSSL is available.\n" .. 
                  "Current random source: " .. random_secure.available .. "\n" ..
                  "Current SHA256 source: " .. sha256_secure.available)
        end
        
        return jwk
    end
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
    
    -- Decode the raw binary value of n
    local n_binary = base64url_decode(jwk.n)
    
    -- Hash the raw binary value
    local hash = sha256(n_binary)
    
    -- Base64URL encode the hash
    local address = base64url_encode(hash)
    
    return address
end

-- Read file with validation
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
    -- Show security info
    io.stderr:write("hbwallet v1.2.0 (secure)\n")
    io.stderr:write("Random source: " .. random_secure.available .. "\n")
    io.stderr:write("SHA256 source: " .. sha256_secure.available .. "\n")
    io.stderr:write("\n")
    
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
        
        local ok, address = pcall(get_wallet_address, jwk)
        if not ok then
            io.stderr:write("Error: " .. address .. "\n")
            os.exit(1)
        end
        
        print(address)
        
    elseif cmd == nil then
        local ok, jwk = pcall(generate_jwk)
        if not ok then
            io.stderr:write("Error: " .. jwk .. "\n")
            io.stderr:write("\nSecurity requirements not met. Please install:\n")
            io.stderr:write("  - LuaCrypto (recommended): luarocks install luacrypto\n")
            io.stderr:write("  - Or ensure OpenSSL is available\n")
            io.stderr:write("  - Or use Lua 5.3+ for bitwise operations\n")
            os.exit(1)
        end
        
        -- Add JWK type
        jwk.kty = "RSA"
        
        -- Output with security warning
        print(json.encode(jwk, { indent = 2 }))
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