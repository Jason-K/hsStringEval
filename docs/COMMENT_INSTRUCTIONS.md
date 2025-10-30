# COMMENTING STYLE GUIDELINES

When documenting additional files, follow these patterns:

## 1. File Header

```lua
--[[
WHAT THIS FILE DOES:
Brief description of the module's purpose and responsibilities.

KEY CONCEPTS:
- Important concept 1
- Important concept 2

EXAMPLE USAGE:
    local Module = require("path.to.module")
    local instance = Module.new()
    instance:doSomething()
]]
```

## 2. Function Documentation

```lua
-- PUBLIC METHOD: Brief description
-- More detailed explanation if needed
-- @param arg1 description of input, including type
-- @param arg2 description of input, including type
-- @return description of output
-- Example: FunctionName(arg1, arg2) → result
function Module:functionName(arg1, arg2)
    -- SETUP: Initialize variables
    local state = {}

    -- GUARD: Check preconditions
    if not arg1 then
        return nil
    end

    -- ACTION: Main logic
    local result = doSomething(arg1)

    -- PROCESS: Transform result
    return processResult(result)
end
```

## 3. Comment Prefixes

Use these prefixes to categorize inline comments:

- **SETUP** - Initialize variables, create data structures
- **GUARD** - Precondition checks, early returns, validation
- **ACTION** - Main logic, the "meat" of the function
- **PROCESS** - Transform data, post-process results
- **HELPER** - Utility functions
- **CASE** - Branches in conditionals
- **STEP** - Sequential operations in workflows
- **TRY/FAIL/SUCCESS** - Error handling paths
- **REGISTER** - Store state, cache values
- **CLEANUP** - Tear down, release resources

## 4. Real Examples

Always include concrete examples:

```lua
-- Example: Utils.pathJoin("Users", "jason", "Scripts") → "/Users/jason/Scripts"
```

## 5. Why Comments

Explain non-obvious decisions:

```lua
-- We cache this because computing it requires filesystem access
-- which is slow (dozens of milliseconds)
```
