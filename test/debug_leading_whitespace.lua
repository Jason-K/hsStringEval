#!/usr/bin/env lua

-- Debug test to verify formatSelectionSeed leading whitespace preservation issue

local helper = require("spec_helper")
local strings = helper.requireFresh("utils.strings")

print("=== Debug: formatSelectionSeed Leading Whitespace ===\n")

local testCases = {
    { name = "Leading spaces, no separator", input = "  5+3" },
    { name = "Leading tab, no separator", input = "\t5*2" },
    { name = "Leading newline, no separator", input = "\n10-5" },
    { name = "Leading mixed, no separator", input = "  \t\n3+4" },
    { name = "Leading spaces with = separator", input = "  x=5+3" },
    { name = "Leading spaces with : separator", input = "  result:10*2" },
}

for _, test in ipairs(testCases) do
    print(string.format("--- Test: %s ---", test.name))
    print(string.format("Input: '%s'", test.input:gsub("\n", "\\n"):gsub("\t", "\\t")))

    -- Simulate what formatSelectionSeed does
    local leading_ws = test.input:match("^(%s*)") or ""
    local trailing_ws = test.input:match("(%s*)$") or ""
    local body = test.input:sub(1, #test.input - #trailing_ws)

    print(string.format("Leading whitespace: '%s'", leading_ws:gsub("\n", "\\n"):gsub("\t", "\\t")))
    print(string.format("Trailing whitespace: '%s'", trailing_ws:gsub("\n", "\\n"):gsub("\t", "\\t")))
    print(string.format("Body: '%s'", body:gsub("\n", "\\n"):gsub("\t", "\\t")))

    local prefix, seed = strings.extractSeed(body)

    print(string.format("Prefix: '%s'", prefix:gsub("\n", "\\n"):gsub("\t", "\\t")))
    print(string.format("Seed: '%s'", seed:gsub("\n", "\\n"):gsub("\t", "\\t")))

    -- Check the condition
    local isWhitespaceOnly = prefix:match("^%s*$")
    local isEmpty = prefix == ""

    print(string.format("Is whitespace-only: %s", tostring(isWhitespaceOnly)))
    print(string.format("Is empty: %s", tostring(isEmpty)))

    -- What would be returned? (AFTER FIX)
    local formatted = "8" -- Assume 5+3 = 8 for simplicity
    local result
    if isWhitespaceOnly or isEmpty then
        result = leading_ws .. formatted .. trailing_ws
        print(string.format("Branch: whitespace-only or empty -> result: '%s'", result:gsub("\n", "\\n"):gsub("\t", "\\t")))
    else
        result = prefix .. formatted .. trailing_ws
        print(string.format("Branch: normal -> result: '%s'", result:gsub("\n", "\\n"):gsub("\t", "\\t")))
    end

    -- Check if leading whitespace is preserved
    local leadingPreserved = result:sub(1, #leading_ws) == leading_ws
    print(string.format("Leading whitespace preserved: %s", tostring(leadingPreserved)))

    if not leadingPreserved then
        print("❌ LEADING WHITESPACE LOST!")
    else
        print("✓ Leading whitespace preserved")
    end

    print()
end
