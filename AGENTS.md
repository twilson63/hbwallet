# hbwallet Development Guide for AI Agents

## Build/Test Commands
- Build: `make build` or `hype build src/hbwallet.lua -o hbwallet`
- Run all tests: `make test` or `lua test/run_tests.lua`
- Run single test file: `lua test/test_jwk_generation.lua` (requires test framework)
- Build and test: `make test-all` or `./test/build_and_test.sh`
- Clean: `make clean`

## Code Style Guidelines
- **Language**: Lua 5.3 (with LuaJIT compatibility)
- **Framework**: Hype - https://twilson63.github.io/hype (Lua application framework)
- **Indentation**: 4 spaces, no tabs
- **Comments**: Use `--` for single-line comments, document functions and modules
- **Naming**: snake_case for functions/variables, PascalCase for modules
- **Requires**: Place all requires at top of file (e.g., `local ffi = require("ffi")`)
- **Locals**: Always use `local` for variables and functions unless global is needed
- **Tables**: Use `{}` for empty tables, align multi-line table entries
- **Strings**: Use double quotes for strings, single quotes for character literals
- **Error Handling**: Use `pcall()` for operations that may fail, return nil,error pattern
- **Module Pattern**: Return table with public functions at end of file
- **Testing**: Use test.suite() with descriptive test names, assert_* functions
- **No external deps**: Core functionality uses only Hype framework built-ins