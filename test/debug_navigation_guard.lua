#!/usr/bin/env lua

--[[
Test the looksLikeArithmetic function in navigation detector
This is the guard that should prevent navigation from matching arithmetic
]]

-- Load spec helper for proper module setup
local helper = require("spec_helper")
local strings = helper.requireFresh("utils.strings")

-- Replicate the looksLikeArithmetic function from navigation.lua
local function looksLikeArithmetic(text)
    if type(text) ~= "string" then return false end
    local trimmed = strings.trim(text)
    -- Strip dollar signs before checking if it's an arithmetic expression
    -- This allows expressions like "$120-$50" to be recognized as arithmetic
    local withoutCurrency = trimmed:gsub("%$", "")
    -- Check if it's a simple arithmetic expression (numbers and operators only)
    -- Include 'c' and 'C' for combination operations (e.g., "12c12")
    local result = withoutCurrency:match("^[%d%.%s%(%)%+%-%*/%%^cC]+$") ~= nil
    return result
end

print("=== Testing looksLikeArithmetic guard ===\n")

local testCases = {
    { name = "With leading whitespace", input = "      $14645-13340-2196.75" },
    { name = "Without leading whitespace", input = "$14645-13340-2196.75" },
    { name = "Just the seed", input = "$14645-13340-2196.75" },
    { name = "Without dollar sign", input = "14645-13340-2196.75" },
    { name = "Simple arithmetic", input = "120-50" },
    { name = "Empty string", input = "" },
    { name = "Just whitespace", input = "     " },
    { name = "Non-arithmetic text", input = "hello world" },
    { name = "URL", input = "https://example.com" },
    { name = "File path", input = "~/Documents/file.txt" },
    { name = "With newline character", input = "$14645-13340-2196.75\n" },
    { name = "With tab character", input = "\t$14645-13340-2196.75" },
}

for _, test in ipairs(testCases) do
    local result = looksLikeArithmetic(test.input)
    local input_repr = test.input:gsub("\n", "\\n"):gsub("\t", "\\t"):gsub("\r", "\\r")
    print(string.format("%s: '%s' -> %s", test.name, input_repr, tostring(result)))
end

print("\n=== Checking for hidden characters ===")

-- The actual user input
local userInput = "      $14645-13340-2196.75"
print(string.format("User input length: %d", #userInput))
print("Character breakdown:")
for i = 1, #userInput do
    local byte = userInput:byte(i)
    local char = userInput:sub(i, i)
    local charName = char
    if char == " " then charName = "SPACE" end
    print(string.format("  [%d] = '%s' (byte: %d = 0x%02x)", i, charName, byte, byte))
end

print("\n=== Test complete ===")
