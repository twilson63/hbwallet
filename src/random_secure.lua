-- Secure random number generation for hbwallet
-- Uses cryptographically secure sources

local random = {}

-- Try to use LuaCrypto if available
local ok, crypto = pcall(require, "crypto")
if ok and crypto.rand then
    function random.bytes(n)
        return crypto.rand.bytes(n)
    end
    random.available = "luacrypto"
    return random
end

-- Try to use OpenSSL via FFI if available
local ok, ffi = pcall(require, "ffi")
if ok then
    local ok_ssl = pcall(function()
        ffi.cdef[[
            int RAND_bytes(unsigned char *buf, int num);
        ]]
        
        local ssl = ffi.load("ssl")
        
        function random.bytes(n)
            local buf = ffi.new("unsigned char[?]", n)
            if ssl.RAND_bytes(buf, n) ~= 1 then
                error("RAND_bytes failed")
            end
            return ffi.string(buf, n)
        end
        
        random.available = "openssl-ffi"
        return random
    end)
    
    if ok_ssl then
        return random
    end
end

-- Use /dev/urandom on Unix-like systems
local function has_dev_urandom()
    local f = io.open("/dev/urandom", "rb")
    if f then
        f:close()
        return true
    end
    return false
end

if has_dev_urandom() then
    function random.bytes(n)
        local f = io.open("/dev/urandom", "rb")
        if not f then
            error("Cannot open /dev/urandom")
        end
        local data = f:read(n)
        f:close()
        if not data or #data ~= n then
            error("Failed to read from /dev/urandom")
        end
        return data
    end
    random.available = "/dev/urandom"
    return random
end

-- Windows: Try to use BCrypt via FFI
if ok and ffi.os == "Windows" then
    local ok_bcrypt = pcall(function()
        ffi.cdef[[
            typedef void* BCRYPT_ALG_HANDLE;
            typedef long NTSTATUS;
            
            NTSTATUS BCryptOpenAlgorithmProvider(
                BCRYPT_ALG_HANDLE *phAlgorithm,
                const wchar_t *pszAlgId,
                const wchar_t *pszImplementation,
                unsigned long dwFlags
            );
            
            NTSTATUS BCryptGenRandom(
                BCRYPT_ALG_HANDLE hAlgorithm,
                unsigned char *pbBuffer,
                unsigned long cbBuffer,
                unsigned long dwFlags
            );
            
            NTSTATUS BCryptCloseAlgorithmProvider(
                BCRYPT_ALG_HANDLE hAlgorithm,
                unsigned long dwFlags
            );
        ]]
        
        local bcrypt = ffi.load("Bcrypt")
        local BCRYPT_USE_SYSTEM_PREFERRED_RNG = 0x00000002
        
        function random.bytes(n)
            local buf = ffi.new("unsigned char[?]", n)
            local status = bcrypt.BCryptGenRandom(nil, buf, n, BCRYPT_USE_SYSTEM_PREFERRED_RNG)
            if status ~= 0 then
                error("BCryptGenRandom failed: " .. status)
            end
            return ffi.string(buf, n)
        end
        
        random.available = "bcrypt"
        return random
    end)
    
    if ok_bcrypt then
        return random
    end
end

-- Fallback: Try os.execute with proper escaping (last resort)
local function shell_escape(str)
    -- Convert to hex to avoid any shell interpretation
    local hex = ""
    for i = 1, #str do
        hex = hex .. string.format("%02x", str:byte(i))
    end
    return hex
end

local function try_system_random(n)
    local tmpfile = os.tmpname()
    local success = false
    local data = nil
    
    -- Try different commands
    local commands = {
        -- Unix-like systems
        string.format("dd if=/dev/urandom of=%s bs=%d count=1 2>/dev/null", tmpfile, n),
        -- macOS/BSD
        string.format("head -c %d /dev/urandom > %s 2>/dev/null", n, tmpfile),
        -- Windows PowerShell
        string.format('powershell -Command "[byte[]]$bytes = 1..%d | ForEach {Get-Random -Maximum 256}; [System.IO.File]::WriteAllBytes(\'%s\', $bytes)"', n, tmpfile:gsub("\\", "\\\\"))
    }
    
    for _, cmd in ipairs(commands) do
        if os.execute(cmd) == 0 then
            local f = io.open(tmpfile, "rb")
            if f then
                data = f:read("*a")
                f:close()
                if data and #data == n then
                    success = true
                    break
                end
            end
        end
    end
    
    os.remove(tmpfile)
    
    if success then
        return data
    else
        error("No secure random source available")
    end
end

-- Last resort fallback
function random.bytes(n)
    local ok, data = pcall(try_system_random, n)
    if ok then
        random.available = "system"
        return data
    else
        error("No secure random source available. Please install LuaCrypto or use a system with /dev/urandom")
    end
end

random.available = "fallback"

return random