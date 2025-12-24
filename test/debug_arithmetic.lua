#!/usr/bin/env lua

--[[
Diagnostic test to trace arithmetic detector failure
This script reproduces the issue where "$14645-13340-2196.75" fails to match
]]

-- Load spec helper for proper module setup
local helper = require("spec_helper")

-- Load required modules
local strings = helper.requireFresh("utils.strings")
local patterns = helper.requireFresh("utils.patterns")
local Arithmetic = helper.requireFresh("formatters.arithmetic")

-- Test cases based on logs
local testCases = {
    {
        name = "Original issue - with leading whitespace",
        input = "      $14645-13340-2196.75",
    },
    {
        name = "Without leading whitespace",
        input = "$14645-13340-2196.75",
    },
    {
        name = "Without dollar sign",
        input = "14645-13340-2196.75",
    },
    {
        name = "Simple arithmetic",
        input = "120-50",
    },
    {
        name = "With currency prefix",
        input = "$120-$50",
    },
}

print("=== Arithmetic Detector Diagnostic Test ===\n")

for _, test in ipairs(testCases) do
    print(string.format("\n--- Test: %s ---", test.name))
    print(string.format("Input: '%s'", test.input))
    print(string.format("Input length: %d", #test.input))

    -- Step 1: Normalize minus
    local normalized = strings.normalizeMinus(test.input)
    print(string.format("After normalizeMinus: '%s'", normalized))

    -- Step 2: Trim
    local trimmed = strings.trim(normalized)
    print(string.format("After trim: '%s'", trimmed))
    print(string.format("Trimmed length: %d", #trimmed))

    -- Step 3: Check date pattern (should NOT match)
    local datePattern = patterns.compiled("date_full")
    local dateMatch = datePattern.match(trimmed)
    print(string.format("Date pattern match: %s", tostring(dateMatch)))

    -- Step 4: Check arithmetic candidate pattern
    local arithmeticPattern = patterns.compiled("arithmetic_candidate")
    local arithMatch = arithmeticPattern.match(trimmed)
    print(string.format("Arithmetic candidate pattern: '%s'", arithmeticPattern.raw))
    print(string.format("Arithmetic pattern match: %s", tostring(arithMatch)))

    -- Step 5: Remove currency and whitespace
    local removeCurrencyAndWhitespace = function(str)
        return (str or ""):gsub("%$", ""):gsub("%s+", "")
    end
    local stripped = removeCurrencyAndWhitespace(trimmed)
    print(string.format("After removeCurrencyAndWhitespace: '%s'", stripped))

    -- Step 6: Check for invalid characters
    local hasInvalid = stripped:find("[^%d%.%(%)%+%-%*/%%^]")
    print(string.format("Has invalid characters: %s", tostring(hasInvalid)))

    if hasInvalid then
        -- Find what the invalid character is
        for i = 1, #stripped do
            local char = stripped:sub(i, i)
            if not char:match("[%d%.%(%)%+%-%*/%%^]") then
                print(string.format("  Invalid char at position %d: '%s' (byte: %d)", i, char, char:byte()))
            end
        end
    end

    -- Step 7: Final isCandidate check
    local isCandidate = Arithmetic.isCandidate(test.input, { patterns = patterns.all() })
    print(string.format("isCandidate result: %s", tostring(isCandidate)))

    -- Step 8: If candidate, try processing
    if isCandidate then
        local result = Arithmetic.process(test.input, { patterns = patterns.all() })
        print(string.format("Process result: %s", tostring(result)))
    else
        print("Process result: SKIPPED (not a candidate)")
    end
end

print("\n=== Diagnostic Test Complete ===")
