#!/usr/bin/env lua

--[[
Test what happens when there's text before the arithmetic expression
This is the key scenario - the user said "input may include any other text that precedes the input string"
]]

-- Load spec helper for proper module setup
local helper = require("spec_helper")

-- Load required modules
local strings = helper.requireFresh("utils.strings")
local patterns = helper.requireFresh("utils.patterns")
local RegistryFactory = helper.requireFresh("detectors.registry")
local ArithmeticConstructor = helper.requireFresh("detectors.arithmetic")
local NavigationConstructor = helper.requireFresh("detectors.navigation")

-- Create a simple logger
local logger = {
    d = function(msg)
        print(string.format("  [DEBUG] %s", msg))
    end,
    e = function(msg)
        print(string.format("  [ERROR] %s", msg))
    end,
    w = function(msg)
        print(string.format("  [WARN] %s", msg))
    end,
}

-- Create detectors with dependencies
local deps = {
    logger = logger,
    config = {},
    formatters = {
        arithmetic = helper.requireFresh("formatters.arithmetic"),
    },
}

local arithmeticDetector = ArithmeticConstructor(deps)
local navigationDetector = NavigationConstructor(deps)

-- Create registry
local registry = RegistryFactory.new(logger)
registry:register(arithmeticDetector)
registry:register(navigationDetector)

print("=== Testing with Text Prefix Before Arithmetic ===\n")

local testCases = {
    { name = "Text with colon then arithmetic", input = "Some text: $14645-13340-2196.75" },
    { name = "Text with equals then arithmetic", input = "Result = $14645-13340-2196.75" },
    { name = "Just label with spaces", input = "Total      $14645-13340-2196.75" },
    { name = "Sentence ending with arithmetic", input = "The answer is $14645-13340-2196.75" },
    { name = "Multiple words then arithmetic", input = "Here is the calculation $14645-13340-2196.75" },
}

for _, test in ipairs(testCases) do
    print(string.format("--- Test: %s ---", test.name))
    print(string.format("Input: '%s'", test.input))
    print()

    -- Simulate formatSelectionSeed
    print("Step 1: Extract seed")
    local leading_ws = test.input:match("^(%s*)") or ""
    local trailing_ws = test.input:match("(%s*)$") or ""
    local body = test.input:sub(1, #test.input - #trailing_ws)
    local prefix, seed = strings.extractSeed(body)
    print(string.format("  Leading whitespace: '%s'", leading_ws))
    print(string.format("  Prefix: '%s'", prefix))
    print(string.format("  Seed: '%s'", seed))
    print()

    print("Step 2: Process seed through registry")
    local context = {}
    local matched, matchedId, rawResult = registry:process(seed, context)
    print(string.format("  Matched: '%s'", tostring(matched)))
    print(string.format("  Matched ID: '%s'", tostring(matchedId)))
    print(string.format("  Context.__matched: %s", tostring(context.__matched)))
    print(string.format("  Context.__lastMatchId: %s", tostring(context.__lastMatchId)))

    if context.__lastSideEffect and type(context.__lastSideEffect) == "table" then
        print(string.format("  Side effect type: %s", context.__lastSideEffect.type))
        if context.__lastSideEffect.type == "kagi_search" then
            print("  *** KAGI SEARCH TRIGGERED! ***")
        end
    end
    print()
end

print("=== Test complete ===")
