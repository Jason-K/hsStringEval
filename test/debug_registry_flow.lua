#!/usr/bin/env lua

--[[
Diagnostic test to trace the full registry flow
This simulates what happens when FormatCutSeed calls the detectors
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

-- Test case that simulates the actual user scenario
print("=== Registry Flow Diagnostic Test ===\n")

local testInput = "      $14645-13340-2196.75"
print(string.format("Input: '%s'", testInput))
print(string.format("Input length: %d", #testInput))
print()

-- Simulate what formatSelectionSeed does
print("--- Simulating formatSelectionSeed flow ---")
print()

print("Step 1: Extract seed from input")
local leading_ws = testInput:match("^(%s*)") or ""
local trailing_ws = testInput:match("(%s*)$") or ""
local body = testInput:sub(1, #testInput - #trailing_ws)
local prefix, seed = strings.extractSeed(body)
print(string.format("  Leading whitespace: '%s'", leading_ws))
print(string.format("  Trailing whitespace: '%s'", trailing_ws))
print(string.format("  Body: '%s'", body))
print(string.format("  Prefix: '%s'", prefix))
print(string.format("  Seed: '%s'", seed))
print()

print("Step 2: Process seed through detector registry")
print("Detectors registered:")
for i, det in ipairs(registry.detectors) do
    print(string.format("  %d. %s (priority: %d)", i, det.id, det.priority))
end
print()

print("Step 3: Call registry:process() on seed")
local context = {}
local matched, matchedId, rawResult = registry:process(seed, context)
print()
print(string.format("Result: matched='%s', matchedId='%s'", tostring(matched), tostring(matchedId)))
print(string.format("Raw result type: %s", type(rawResult)))
if type(rawResult) == "table" then
    print("Raw result fields:")
    for k, v in pairs(rawResult) do
        print(string.format("  %s: %s", k, tostring(v)))
    end
end
print()
print(string.format("Context.__matched: %s", tostring(context.__matched)))
print(string.format("Context.__lastMatchId: %s", tostring(context.__lastMatchId)))
if context.__matches then
    print(string.format("Context.__matches count: %d", #context.__matches))
    for i, m in ipairs(context.__matches) do
        print(string.format("  Match %d: id=%s", i, m.id))
    end
end
print()
print(string.format("Context.__lastSideEffect type: %s", type(context.__lastSideEffect)))
if context.__lastSideEffect and type(context.__lastSideEffect) == "table" then
    print("Side effect fields:")
    for k, v in pairs(context.__lastSideEffect) do
        print(string.format("  %s: %s", k, tostring(v)))
    end
end
print()

-- Additional test: what if we process the original input with whitespace?
print("--- Additional test: Process original input (without seed extraction) ---")
local context2 = {}
local matched2, matchedId2, rawResult2 = registry:process(testInput, context2)
print()
print(string.format("Result: matched='%s', matchedId='%s'", tostring(matched2), tostring(matchedId2)))
print(string.format("Context.__lastMatchId: %s", tostring(context2.__lastMatchId)))
if context2.__lastSideEffect and type(context2.__lastSideEffect) == "table" then
    print(string.format("Side effect type: %s", context2.__lastSideEffect.type))
end

print("\n=== Diagnostic Test Complete ===")
