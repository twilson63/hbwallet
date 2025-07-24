-- Simple JSON module for tests
-- Extracts the JSON implementation from hbwallet

local json = {}

-- JSON decode implementation (simplified for tests)
function json.decode(str)
    local pos = 1
    
    local function skip_whitespace()
        while pos <= #str and str:sub(pos, pos):match("[ \t\r\n]") do
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
            while pos <= #str and str:sub(pos, pos) ~= '"' do
                if str:sub(pos, pos) == '\\' then
                    pos = pos + 2
                else
                    pos = pos + 1
                end
            end
            local value = str:sub(start, pos-1)
            pos = pos + 1
            return value
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

return json