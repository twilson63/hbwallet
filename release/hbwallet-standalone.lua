#!/usr/bin/env lua

-- hbwallet standalone version with embedded dependencies

-- Embedded JSON module
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

-- Base64 encoding
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

-- Simple SHA256 (placeholder - in production use proper crypto)
local function sha256(data)
    -- This is a simplified hash for demonstration
    -- Real implementation would use proper SHA256
    local hash = 0
    for i = 1, #data do
        hash = (hash * 31 + string.byte(data, i)) % 2^32
    end
    
    -- Convert to bytes
    local bytes = {}
    for i = 1, 32 do
        bytes[i] = string.char(hash % 256)
        hash = math.floor(hash / 256)
        if hash == 0 then
            hash = i * 12345
        end
    end
    
    return table.concat(bytes)
end

-- Generate random bytes
local function random_bytes(n)
    -- Better random seed
    local seed = os.time()
    local clock = os.clock() * 1000000
    math.randomseed(seed + math.floor(clock) % 1000000)
    
    local bytes = {}
    for i = 1, n do
        bytes[i] = string.char(math.random(0, 255))
    end
    return table.concat(bytes)
end

-- Generate RSA-like JWK
local function generate_jwk()
    -- Generate random key components
    -- In production, use proper RSA key generation
    local n = base64url_encode(random_bytes(512))  -- 4096 bits
    local e = "AQAB"  -- Standard exponent 65537
    local d = base64url_encode(random_bytes(512))  -- 4096 bits
    local p = base64url_encode(random_bytes(256))  -- 2048 bits
    local q = base64url_encode(random_bytes(256))  -- 2048 bits
    local dp = base64url_encode(random_bytes(256)) -- 2048 bits
    local dq = base64url_encode(random_bytes(256)) -- 2048 bits
    local qi = base64url_encode(random_bytes(256)) -- 2048 bits
    
    return {
        kty = "RSA",
        n = n,
        e = e,
        d = d,
        p = p,
        q = q,
        dp = dp,
        dq = dq,
        qi = qi
    }
end

-- Get wallet address from JWK
local function get_wallet_address(jwk)
    local public_key = {
        e = jwk.e,
        kty = jwk.kty,
        n = jwk.n
    }
    
    local public_json = json.encode(public_key, { sort_keys = true })
    local hash = sha256(public_json)
    local address = base64url_encode(hash)
    
    return address:sub(1, 43)
end

-- Read file
local function read_file(filename)
    local file = io.open(filename, "r")
    if not file then
        io.stderr:write("Error: Cannot open file " .. filename .. "\n")
        os.exit(1)
    end
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
        
        local address = get_wallet_address(jwk)
        print(address)
        
    elseif cmd == nil then
        local jwk = generate_jwk()
        print(json.encode(jwk, { indent = 2 }))
        
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