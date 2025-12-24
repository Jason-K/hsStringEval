#!/usr/bin/env lua

--[[
Test edge cases that might cause looksLikeArithmetic to return false
]]

-- Load spec helper for proper module setup
local helper = require("spec_helper")
local strings = helper.requireFresh("utils.strings")

-- Replicate the looksLikeArithmetic function from navigation.lua
local function looksLikeArithmetic(text)
    if type(text) ~= "string" then return false end
    local trimmed = strings.trim(text)
    local withoutCurrency = trimmed:gsub("%$", "")
    local result = withoutCurrency:match("^[%d%.%s%(%)%+%-%*/%%^cC]+$") ~= nil
    return result
end

print("=== Edge Cases That Could Break looksLikeArithmetic ===\n")

local edgeCases = {
    { name = "Normal arithmetic", input = "$14645-13340-2196.75" },
    { name = "With special Unicode minus", input = "$14645−13340−2196.75" },  -- Using minus sign instead of hyphen
    { name = "With en dash", input = "$14645–13340–2196.75" },
    { name = "With em dash", input = "$14645—13340—2196.75" },
    { name = "With fancy Unicode spaces", input = "$14645-13340-2196.75\u{2002}" },  -- en space
    { name = "With non-breaking space", input = "$14645-13340-2196.75\u{00A0}" },
    { name = "With zero-width space", input = "$14645-13340-2196.75\u{200B}" },
    { name = "Multiple dollar signs in middle", input = "$14645-$$$13340-2196.75" },
    { name = "Dollar at end", input = "14645-13340-2196.75$" },
    { name = "With percentage", input = "$14645-13340-2196.75%" },
    { name = "With brackets", input = "$(14645-13340)-2196.75" },
    { name = "Text then dollar", input = "Total $14645-13340" },
    { name = "Just text", input = "hello world" },
    { name = "Empty after trim", input = "   " },
}

for _, test in ipairs(edgeCases) do
    local result = looksLikeArithmetic(test.input)
    local input_repr = test.input:gsub("\u{2002}", "\\u{2002}"):gsub("\u{00A0}", "\\u{00A0}"):gsub("\u{200B}", "\\u{200B}")
    local status = result and "✓ PASS" or "✗ FAIL"
    print(string.format("%s: '%s' -> %s", status, input_repr, tostring(result)))

    -- If this unexpectedly returns false for arithmetic, show details
    if not result and test.input:match("%$") and test.input:match("%d") then
        print("  ^ This should probably be true!")
    end
end

print("\n=== Analyzing Actual Seed Extraction Results ===")

-- Test what extractSeed actually returns for various inputs
local testInputs = {
    "$14645-13340-2196.75",
    "      $14645-13340-2196.75",
    "Some text: $14645-13340-2196.75",
    "$14645-13340-2196.75\n",
    "\t$14645-13340-2196.75",
}

for _, input in ipairs(testInputs) do
    local prefix, seed = strings.extractSeed(input)
    local looksArith = looksLikeArithmetic(seed)
    local input_repr = input:gsub("\n", "\\n"):gsub("\t", "\\t")
    print(string.format("Input: '%s'", input_repr))
    print(string.format("  Seed: '%s'", seed))
    print(string.format("  looksLikeArithmetic: %s", tostring(looksArith)))
    if not looksArith then
        print("  ^^^ WARNING: Navigation will match this! ^^^")
    end
    print()
end

print("=== Test complete ===")
