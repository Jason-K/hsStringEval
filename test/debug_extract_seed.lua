#!/usr/bin/env lua

--[[
Test the extractSeed function to confirm the root cause
]]

-- Load spec helper for proper module setup
local helper = require("spec_helper")
local strings = helper.requireFresh("utils.strings")

print("=== Testing extractSeed function ===\n")

local testCases = {
    { name = "With dollar and spaces", input = "      $14645-13340-2196.75" },
    { name = "Just dollar expression", input = "$14645-13340-2196.75" },
    { name = "Without dollar", input = "14645-13340-2196.75" },
    { name = "Text prefix with dollar", input = "Total: $14645-13340" },
    { name = "Text prefix without dollar", input = "Total: 14645-13340" },
    { name = "Empty string", input = "" },
    { name = "Just spaces", input = "     " },
}

for _, test in ipairs(testCases) do
    local prefix, seed = strings.extractSeed(test.input)
    print(string.format("--- %s ---", test.name))
    print(string.format("Input: '%s'", test.input))
    print(string.format("Prefix: '%s'", prefix))
    print(string.format("Seed: '%s'", seed))
    print()
end

print("=== Test complete ===")
