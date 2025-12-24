#!/usr/bin/env lua

--[[
Simulate what happens when formatSelectionSeed is called multiple times
This reproduces the double-call scenario from the logs
]]

-- Load spec helper for proper module setup
local helper = require("spec_helper")

-- Load required modules
local strings = helper.requireFresh("utils.strings")
local patterns = helper.requireFresh("utils.patterns")
local RegistryFactory = helper.requireFresh("detectors.registry")
local ArithmeticConstructor = helper.requireFresh("detectors.arithmetic")
local NavigationConstructor = helper.requireFresh("detectors.navigation")

-- Create a simple logger that tracks all calls
local callLog = {}
local logger = {
    d = function(msg)
        table.insert(callLog, { level = "DEBUG", msg = msg })
        print(string.format("  [DEBUG] %s", msg))
    end,
    e = function(msg)
        table.insert(callLog, { level = "ERROR", msg = msg })
        print(string.format("  [ERROR] %s", msg))
    end,
    w = function(msg)
        table.insert(callLog, { level = "WARN", msg = msg })
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

print("=== Simulating formatSelectionSeed Double Call ===\n")

-- The user's actual input scenario
local testInput = "      $14645-13340-2196.75"
print(string.format("Original input: '%s'", testInput))
print()

-- Simulate first call
print("--- First call to formatSelectionSeed ---")
callLog = {}
local leading_ws = testInput:match("^(%s*)") or ""
local trailing_ws = testInput:match("(%s*)$") or ""
local body = testInput:sub(1, #testInput - #trailing_ws)
local prefix1, seed1 = strings.extractSeed(body)
print(string.format("Extracted seed: '%s'", seed1))

local context1 = {}
local matched1, matchedId1, rawResult1 = registry:process(seed1, context1)
print(string.format("Result: matched='%s', matchedId='%s'", tostring(matched1), tostring(matchedId1)))
print(string.format("Context.__matched: %s", tostring(context1.__matched)))
print(string.format("Context.__lastMatchId: %s", tostring(context1.__lastMatchId)))
print()

-- Simulate second call (what if the context is reused?)
print("--- Second call to formatSelectionSeed (with fresh context) ---")
callLog = {}
local prefix2, seed2 = strings.extractSeed(body)
print(string.format("Extracted seed: '%s'", seed2))

local context2 = {}
local matched2, matchedId2, rawResult2 = registry:process(seed2, context2)
print(string.format("Result: matched='%s', matchedId='%s'", tostring(matched2), tostring(matchedId2)))
print(string.format("Context.__matched: %s", tostring(context2.__matched)))
print(string.format("Context.__lastMatchId: %s", tostring(context2.__lastMatchId)))
print()

-- Test: What if seed extraction fails or returns something unexpected?
print("--- Testing edge case: What if seed has unexpected characters? ---")

-- Try adding a newline at the end (common copy-paste issue)
local inputWithNewline = testInput .. "\n"
print(string.format("Input with newline: '%s'", inputWithNewline:gsub("\n", "\\n")))
callLog = {}
local leading_ws3 = inputWithNewline:match("^(%s*)") or ""
local trailing_ws3 = inputWithNewline:match("(%s*)$") or ""
local body3 = inputWithNewline:sub(1, #inputWithNewline - #trailing_ws3)
local prefix3, seed3 = strings.extractSeed(body3)
print(string.format("Extracted seed: '%s'", seed3:gsub("\n", "\\n")))

local context3 = {}
local matched3, matchedId3, rawResult3 = registry:process(seed3, context3)
print(string.format("Result: matched='%s', matchedId='%s'", tostring(matched3), tostring(matchedId3)))
print()

print("=== Test complete ===")
