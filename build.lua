-- Build script for hbwallet using Hype framework
-- Creates a single binary executable

local hype = require("hype")

-- Configure the build
local config = {
    name = "hbwallet",
    version = "1.0.0",
    description = "Arweave JWK wallet generator",
    author = "hbwallet",
    license = "MIT",
    
    -- Main entry point
    main = "src/hbwallet.lua",
    
    -- Output binary name
    output = "hbwallet",
    
    -- Dependencies to bundle
    modules = {
        "src.hbwallet",
        "src.jwk",
        "src.crypto_openssl",
        "json",
        "mime",
        "sha2"
    },
    
    -- External libraries (OpenSSL)
    libs = {
        "ssl",
        "crypto"
    },
    
    -- Build flags
    flags = {
        strip = true,  -- Strip debug symbols
        static = false  -- Dynamic linking for OpenSSL
    }
}

-- Build the binary
local function build()
    print("Building hbwallet...")
    
    -- Create build directory
    os.execute("mkdir -p build")
    
    -- Use Hype to bundle everything
    local ok, err = hype.build(config)
    
    if ok then
        print("Build successful! Binary created: " .. config.output)
        print("\nUsage:")
        print("  ./hbwallet                            # Generate new wallet")
        print("  ./hbwallet public-key --file wallet   # Get wallet address")
    else
        print("Build failed: " .. tostring(err))
        os.exit(1)
    end
end

-- Run build
build()