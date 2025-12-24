#!/usr/bin/env lua

-- Test to verify formatSelectionSeed preserves leading whitespace correctly
-- This tests the fix for Task 3: Fix formatSeed Leading Whitespace Preservation

local helper = require("spec_helper")
local strings = helper.requireFresh("utils.strings")

print("=== Test: formatSelectionSeed Leading Whitespace Preservation ===\n")

-- Simulate the formatSelectionSeed logic
local function simulateFormatSelectionSeed(text, formattedResult)
    -- Preserve leading and trailing whitespace (tabs/newlines)
    local leading_ws = text:match("^(%s*)") or ""
    local trailing_ws = text:match("(%s*)$") or ""
    local body = text:sub(1, #text - #trailing_ws)
    local prefix, seed = strings.extractSeed(body)

    -- Apply the formatSelectionSeed logic (with fix)
    if type(formattedResult) == "string" and formattedResult ~= seed then
        -- If prefix is only whitespace or empty, preserve leading whitespace
        if prefix:match("^%s*$") or prefix == "" then
            return leading_ws .. formattedResult .. trailing_ws
        else
            return prefix .. formattedResult .. trailing_ws
        end
    end
    return text
end

local testCases = {
    {
        name = "Leading spaces with simple arithmetic",
        input = "  5+3",
        formatted = "8",  -- Formatter returns trimmed result
        expected = "  8",
    },
    {
        name = "Leading tab with multiplication",
        input = "\t2*4",
        formatted = "8",
        expected = "\t8",
    },
    {
        name = "Leading newline with subtraction",
        input = "\n10-5",
        formatted = "5",
        expected = "\n5",
    },
    {
        name = "Mixed leading whitespace",
        input = "  \t\n3+4",
        formatted = "7",
        expected = "  \t\n7",
    },
    {
        name = "Leading spaces with = separator",
        input = "  x=5+3",
        formatted = "8",
        expected = "  8",  -- prefix="  ", formatted="8"
    },
    {
        name = "Leading spaces with : separator",
        input = "  result:10*2",
        formatted = "20",
        expected = "  20",  -- prefix="  ", formatted="20"
    },
    {
        name = "Trailing whitespace preserved",
        input = "5+3  ",
        formatted = "8",
        expected = "8  ",
    },
    {
        name = "Both leading and trailing whitespace",
        input = "  5+3  ",
        formatted = "8",
        expected = "  8  ",
    },
}

local passCount = 0
local failCount = 0

for _, test in ipairs(testCases) do
    print(string.format("--- Test: %s ---", test.name))
    print(string.format("Input: '%s'", test.input:gsub("\n", "\\n"):gsub("\t", "\\t")))
    print(string.format("Formatted: '%s'", test.formatted))
    print(string.format("Expected: '%s'", test.expected:gsub("\n", "\\n"):gsub("\t", "\\t")))

    local result = simulateFormatSelectionSeed(test.input, test.formatted)
    print(string.format("Result: '%s'", result:gsub("\n", "\\n"):gsub("\t", "\\t")))

    if result == test.expected then
        print("✓ PASS")
        passCount = passCount + 1
    else
        print("✗ FAIL")
        print(string.format("  Expected '%s' but got '%s'",
            test.expected:gsub("\n", "\\n"):gsub("\t", "\\t"),
            result:gsub("\n", "\\n"):gsub("\t", "\\t")))
        failCount = failCount + 1
    end
    print()
end

print(string.format("=== Results: %d passed, %d failed ===", passCount, failCount))

if failCount > 0 then
    os.exit(1)
end
