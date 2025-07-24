-- Simple test framework for hbwallet tests

local M = {}

-- Color codes for terminal output
local colors = {
    green = "\27[32m",
    red = "\27[31m",
    yellow = "\27[33m",
    reset = "\27[0m"
}

-- Test statistics
local stats = {
    total = 0,
    passed = 0,
    failed = 0,
    errors = {}
}

-- Assert functions
function M.assert_equals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s\nExpected: %s\nActual: %s", 
            message or "Values not equal", 
            tostring(expected), 
            tostring(actual)))
    end
end

function M.assert_true(value, message)
    if not value then
        error(message or "Expected true, got false")
    end
end

function M.assert_false(value, message)
    if value then
        error(message or "Expected false, got true")
    end
end

function M.assert_matches(str, pattern, message)
    if not string.match(str, pattern) then
        error(string.format("%s\nString: %s\nPattern: %s", 
            message or "String does not match pattern", 
            str, pattern))
    end
end

function M.assert_length(value, expected_length, message)
    local actual_length = #value
    if actual_length ~= expected_length then
        error(string.format("%s\nExpected length: %d\nActual length: %d",
            message or "Incorrect length",
            expected_length,
            actual_length))
    end
end

function M.assert_type(value, expected_type, message)
    local actual_type = type(value)
    if actual_type ~= expected_type then
        error(string.format("%s\nExpected type: %s\nActual type: %s",
            message or "Incorrect type",
            expected_type,
            actual_type))
    end
end

function M.assert_not_nil(value, message)
    if value == nil then
        error(message or "Expected non-nil value")
    end
end

-- Run a single test
function M.test(name, test_func)
    stats.total = stats.total + 1
    
    io.write(string.format("  %s ... ", name))
    io.flush()
    
    local ok, err = pcall(test_func)
    
    if ok then
        stats.passed = stats.passed + 1
        print(colors.green .. "PASS" .. colors.reset)
    else
        stats.failed = stats.failed + 1
        print(colors.red .. "FAIL" .. colors.reset)
        table.insert(stats.errors, {name = name, error = err})
    end
end

-- Run a test suite
function M.suite(name, tests)
    print(string.format("\n%sRunning test suite: %s%s", colors.yellow, name, colors.reset))
    print(string.rep("-", 50))
    
    for test_name, test_func in pairs(tests) do
        M.test(test_name, test_func)
    end
end

-- Print test summary
function M.summary()
    print(string.format("\n%sSummary:%s", colors.yellow, colors.reset))
    print(string.rep("-", 50))
    print(string.format("Total:  %d", stats.total))
    print(string.format("Passed: %s%d%s", colors.green, stats.passed, colors.reset))
    print(string.format("Failed: %s%d%s", colors.red, stats.failed, colors.reset))
    
    if #stats.errors > 0 then
        print(string.format("\n%sFailures:%s", colors.red, colors.reset))
        for _, error_info in ipairs(stats.errors) do
            print(string.format("\n  Test: %s", error_info.name))
            print(string.format("  Error: %s", error_info.error))
        end
    end
    
    -- Return exit code
    return stats.failed == 0 and 0 or 1
end

-- Helper to run command and capture output
function M.run_command(cmd)
    -- Ensure stderr is captured
    if not string.find(cmd, "2>&1") then
        cmd = cmd .. " 2>&1"
    end
    
    local handle = io.popen(cmd)
    local output = handle:read("*all")
    local result = handle:close()
    
    -- Handle different Lua versions and environments
    local success
    if type(result) == "number" then
        -- Hype or Lua 5.1 - returns exit code directly
        success = result == 0
    elseif type(result) == "boolean" then
        -- Old Lua 5.1 - returns boolean
        success = result
    else
        -- Lua 5.2+ - returns multiple values (we already unpacked them)
        local ok, exit_type, exit_code = result, nil, nil
        success = ok ~= nil and exit_code == 0
    end
    
    return output, success
end

-- Helper to create temporary file
function M.temp_file(content)
    local filename = os.tmpname()
    local file = io.open(filename, "w")
    file:write(content)
    file:close()
    return filename
end

-- Helper to read file
function M.read_file(filename)
    local file = io.open(filename, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

-- Helper to clean up temporary files
function M.cleanup(filename)
    os.remove(filename)
end

return M