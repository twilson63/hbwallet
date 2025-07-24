-- hbwallet v2 - Secure Arweave JWK wallet generator
-- Uses only Hype framework built-in crypto (zero external dependencies)

-- JSON implementation (since Hype doesn't include one)
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
                return "[" .. table.concat(parts, ",") .. "]"
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
                    table.insert(parts, key .. ":" .. value)
                end
                
                if indent and #parts > 0 then
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
        else
            error("Unexpected character: " .. c)
        end
    end
    
    return decode_value()
end

-- Base64 implementation
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local base64 = {}

function base64.encode(data)
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

function base64.decode(str)
    local b64lookup = {}
    for i = 1, 64 do
        b64lookup[b64chars:sub(i,i)] = i - 1
    end
    
    str = str:gsub('[^'..b64chars..'=]', '')
    return (str:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b64lookup[x])
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- Load Hype modules
local crypto = require("crypto")
local httpsig = require("httpsig")

-- Generate 4096-bit RSA JWK using Hype's crypto
local function generate_jwk()
    -- Generate 4096-bit RSA key for Arweave compatibility
    -- Using PS512 (RSA-PSS with SHA-512) for enhanced security
    -- Hype 1.7.4+ supports custom key sizes
    local jwk = crypto.generate_jwk("PS512", 4096)
    
    -- Ensure we have all required fields for Arweave
    if not jwk.kty then jwk.kty = "RSA" end
    
    return jwk
end

-- Get wallet address from JWK (Arweave-compatible)
local function get_wallet_address(jwk)
    -- Validate JWK
    if not jwk or type(jwk) ~= "table" then
        error("Invalid JWK: not a table")
    end
    if not jwk.n or type(jwk.n) ~= "string" then
        error("Invalid JWK: missing or invalid 'n' field")
    end
    
    -- Arweave address = base64url(SHA256(base64url_decode(n)))
    
    -- Decode the modulus from base64url
    local n_b64 = jwk.n:gsub("-", "+"):gsub("_", "/")
    local padding = (4 - #n_b64 % 4) % 4
    n_b64 = n_b64 .. string.rep("=", padding)
    local n_binary = base64.decode(n_b64)
    
    -- Create SHA256 digest
    local digest = httpsig.create_digest(n_binary, "sha256")
    
    -- Extract just the base64 hash (remove "SHA-256=" prefix if present)
    local hash_b64 = digest:match("SHA%-256=(.+)") or digest
    
    -- Convert to base64url
    local address = hash_b64:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
    
    return address
end

-- Read and validate file
local function read_file(filename)
    if filename:match("%.%.") then
        error("Invalid file path")
    end
    
    local file = io.open(filename, "r")
    if not file then
        error("Cannot open file: " .. filename)
    end
    
    local content = file:read("*all")
    file:close()
    
    if #content > 1024 * 1024 then
        error("File too large")
    end
    
    return content
end

-- Parse command line arguments
local function parse_args(args)
    if #args == 0 then
        return "generate", {}
    end
    
    -- Check for help first
    for _, arg in ipairs(args) do
        if arg == "--help" or arg == "-h" then
            return "help", {}
        end
    end
    
    local cmd = args[1]
    local options = {}
    
    local i = 2
    while i <= #args do
        if args[i] == "--file" or args[i] == "-f" then
            if args[i + 1] then
                options.file = args[i + 1]
                i = i + 2
            else
                error("--file requires a filename")
            end
        else
            i = i + 1
        end
    end
    
    return cmd, options
end

-- Show usage
local function show_usage()
    print([[
hbwallet v2 - Arweave JWK wallet generator (Hype-powered)

Usage:
  hbwallet                           Generate new wallet
  hbwallet public-key --file FILE    Get wallet address from JWK file
  hbwallet --help                    Show this help

Examples:
  hbwallet > wallet.json
  hbwallet public-key --file wallet.json

Security: Generated files contain private keys. Keep them secure!
]])
end

-- Main program
local function main()
    local ok, result = pcall(function()
        local cmd, options = parse_args(arg or {})
        
        if cmd == "help" then
            show_usage()
            return
        end
        
        if cmd == "public-key" then
            if not options.file then
                error("--file option required for public-key command")
            end
            
            local content = read_file(options.file)
            local jwk = json.decode(content)
            local address = get_wallet_address(jwk)
            
            print(address)
            
        elseif cmd == "generate" or cmd == nil or cmd == "hbwallet" then
            local jwk = generate_jwk()
            print(json.encode(jwk))
            
            io.stderr:write("\nGenerated new Arweave wallet\n")
            io.stderr:write("WARNING: Keep this file secure - it contains your private key!\n")
            
        else
            error("Unknown command: " .. cmd)
        end
    end)
    
    if not ok then
        io.stderr:write("Error: " .. result .. "\n")
        io.stderr:write("Run 'hbwallet --help' for usage\n")
        os.exit(1)
    end
end

-- Run the program
main()