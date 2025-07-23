#!/usr/bin/env lua

-- Embedded modules
package.preload["json"] = function()
    -- Minimal JSON implementation
    local json = {}
    
    local escape_char_map = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    
    local function escape_char(c)
        return escape_char_map[c] or string.format("\\u%04x", c:byte())
    end
    
    local function encode_string(val)
        return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
    end
    
    local function encode_number(val)
        if val ~= val or val <= -math.huge or val >= math.huge then
            error("Cannot encode number: " .. tostring(val))
        end
        return tostring(val)
    end
    
    local function encode_table(val, stack, indent, current_indent)
        stack = stack or {}
        indent = indent or 0
        current_indent = current_indent or ""
        
        if stack[val] then error("Circular reference") end
        stack[val] = true
        
        local array = true
        local n = 0
        local max_n = 0
        
        for k, v in pairs(val) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                array = false
                break
            end
            n = n + 1
            if k > max_n then max_n = k end
        end
        
        if array and n ~= max_n then array = false end
        
        local parts = {}
        local next_indent = current_indent .. string.rep(" ", indent)
        
        if array then
            for i = 1, max_n do
                parts[i] = json.encode(val[i], stack, indent, next_indent)
            end
            stack[val] = nil
            if indent > 0 then
                return "[\n" .. next_indent .. table.concat(parts, ",\n" .. next_indent) .. "\n" .. current_indent .. "]"
            else
                return "[" .. table.concat(parts, ",") .. "]"
            end
        else
            local keys = {}
            for k in pairs(val) do
                if type(k) == "string" then
                    table.insert(keys, k)
                end
            end
            table.sort(keys)
            
            for _, k in ipairs(keys) do
                local v = val[k]
                table.insert(parts, encode_string(k) .. ":" .. (indent > 0 and " " or "") .. json.encode(v, stack, indent, next_indent))
            end
            
            stack[val] = nil
            if indent > 0 then
                return "{\n" .. next_indent .. table.concat(parts, ",\n" .. next_indent) .. "\n" .. current_indent .. "}"
            else
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
    end
    
    function json.encode(val, stack, indent, current_indent)
        local t = type(val)
        if t == "nil" then
            return "null"
        elseif t == "boolean" then
            return tostring(val)
        elseif t == "number" then
            return encode_number(val)
        elseif t == "string" then
            return encode_string(val)
        elseif t == "table" then
            return encode_table(val, stack, indent, current_indent)
        else
            error("Cannot encode type: " .. t)
        end
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
                -- String
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
                -- Object
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
                
            elseif c == '[' then
                -- Array
                pos = pos + 1
                local arr = {}
                skip_whitespace()
                
                if str:sub(pos, pos) == ']' then
                    pos = pos + 1
                    return arr
                end
                
                while true do
                    table.insert(arr, decode_value())
                    skip_whitespace()
                    
                    local c = str:sub(pos, pos)
                    if c == ']' then
                        pos = pos + 1
                        return arr
                    elseif c == ',' then
                        pos = pos + 1
                    else
                        error("Expected ',' or ']'")
                    end
                end
                
            elseif c == 't' then
                if str:sub(pos, pos+3) == "true" then
                    pos = pos + 4
                    return true
                end
                
            elseif c == 'f' then
                if str:sub(pos, pos+4) == "false" then
                    pos = pos + 5
                    return false
                end
                
            elseif c == 'n' then
                if str:sub(pos, pos+3) == "null" then
                    pos = pos + 4
                    return nil
                end
                
            elseif c:match("[%-0-9]") then
                -- Number
                local start = pos
                if c == '-' then pos = pos + 1 end
                
                while pos <= #str and str:sub(pos, pos):match("[0-9]") do
                    pos = pos + 1
                end
                
                if str:sub(pos, pos) == '.' then
                    pos = pos + 1
                    while pos <= #str and str:sub(pos, pos):match("[0-9]") do
                        pos = pos + 1
                    end
                end
                
                local num_str = str:sub(start, pos-1)
                return tonumber(num_str)
            end
            
            error("Unexpected character: " .. c)
        end
        
        local value = decode_value()
        skip_whitespace()
        
        if pos <= #str then
            error("Extra data after JSON")
        end
        
        return value
    end
    
    return json
end

package.preload["mime"] = function()
    -- Minimal Base64 implementation
    local mime = {}
    
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    
    function mime.b64(data)
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
    
    function mime.unb64(data)
        data = string.gsub(data, '[^'..b64chars..'=]', '')
        return (data:gsub('.', function(x)
            if (x == '=') then return '' end
            local r,f='',(b64chars:find(x)-1)
            for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
            return r;
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
            if (#x ~= 8) then return '' end
            local c=0
            for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
        end))
    end
    
    return mime
end

-- SHA256 implementation
package.preload["sha2"] = function()
    local sha2 = {}
    
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
    
    local function rrotate(n, b)
        return ((n >> b) | (n << (32 - b))) & 0xffffffff
    end
    
    local function sha256_block(msg, h)
        local w = {}
        for i = 1, 16 do
            w[i] = string.unpack(">I4", msg, (i-1)*4 + 1)
        end
        
        for i = 17, 64 do
            local s0 = rrotate(w[i-15], 7) ~ rrotate(w[i-15], 18) ~ (w[i-15] >> 3)
            local s1 = rrotate(w[i-2], 17) ~ rrotate(w[i-2], 19) ~ (w[i-2] >> 10)
            w[i] = (w[i-16] + s0 + w[i-7] + s1) & 0xffffffff
        end
        
        local a, b, c, d, e, f, g, h = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        
        for i = 1, 64 do
            local s1 = rrotate(e, 6) ~ rrotate(e, 11) ~ rrotate(e, 25)
            local ch = (e & f) ~ ((~e) & g)
            local temp1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff
            local s0 = rrotate(a, 2) ~ rrotate(a, 13) ~ rrotate(a, 22)
            local maj = (a & b) ~ (a & c) ~ (b & c)
            local temp2 = (s0 + maj) & 0xffffffff
            
            h = g
            g = f
            f = e
            e = (d + temp1) & 0xffffffff
            d = c
            c = b
            b = a
            a = (temp1 + temp2) & 0xffffffff
        end
        
        h[1] = (h[1] + a) & 0xffffffff
        h[2] = (h[2] + b) & 0xffffffff
        h[3] = (h[3] + c) & 0xffffffff
        h[4] = (h[4] + d) & 0xffffffff
        h[5] = (h[5] + e) & 0xffffffff
        h[6] = (h[6] + f) & 0xffffffff
        h[7] = (h[7] + g) & 0xffffffff
        h[8] = (h[8] + h) & 0xffffffff
    end
    
    function sha2.sha256(msg)
        local h = {
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        }
        
        local len = #msg
        local msg = msg .. "\x80" .. string.rep("\0", (55 - len) % 64) .. string.pack(">I8", len * 8)
        
        for i = 1, #msg, 64 do
            sha256_block(msg:sub(i, i + 63), h)
        end
        
        local result = ""
        for i = 1, 8 do
            result = result .. string.pack(">I4", h[i])
        end
        
        return result
    end
    
    return sha2
end


-- Load embedded hbwallet code
