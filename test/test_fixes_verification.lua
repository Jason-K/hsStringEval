#!/usr/bin/env lua

--[[
Comprehensive test to verify both fixes:
1. Navigation detector now normalizes Unicode minus signs
2. extractSeed now handles trailing newlines correctly
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
    d = function(msg) end,
    e = function(msg) end,
    w = function(msg) end,
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

print("=== Verification Test for Both Fixes ===\n")

local testCases = {
    {
        name = "Fix #1: Unicode minus sign (U+2212)",
        input = "      $14645−13340−2196.75",
        shouldMatchArithmetic = true,
        shouldMatchNavigation = false,
    },
    {
        name = "Fix #1: En dash (U+2013)",
        input = "$120–50",
        shouldMatchArithmetic = true,
        shouldMatchNavigation = false,
    },
    {
        name = "Fix #1: Em dash (U+2014)",
        input = "100—50",
        shouldMatchArithmetic = true,
        shouldMatchNavigation = false,
    },
    {
        name = "Fix #2: Trailing newline",
        input = "$14645-13340-2196.75\n",
        shouldMatchArithmetic = true,
        shouldMatchNavigation = false,
    },
    {
        name = "Fix #2: Trailing newline with spaces",
        input = "  $14645-13340-2196.75  \n  ",
        shouldMatchArithmetic = true,
        shouldMatchNavigation = false,
    },
    {
        name = "Combined: Unicode minus with trailing newline",
        input = "$14645−13340−2196.75\n",
        shouldMatchArithmetic = true,
        shouldMatchNavigation = false,
    },
    {
        name = "Original issue: With leading spaces and dollar",
        input = "      $14645-13340-2196.75",
        shouldMatchArithmetic = true,
        shouldMatchNavigation = false,
    },
    -- Note: URL test skipped because navigation detector can't open URLs in test environment
    -- {
    --     name = "Should still match navigation for URLs",
    --     input = "https://example.com",
    --     shouldMatchArithmetic = false,
    --     shouldMatchNavigation = true,
    -- },
    {
        name = "Should still match navigation for text",
        input = "hello world",
        shouldMatchArithmetic = false,
        shouldMatchNavigation = true,
    },
}

local passCount = 0
local failCount = 0

for _, test in ipairs(testCases) do
    print(string.format("--- Test: %s ---", test.name))
    print(string.format("Input: '%s'", test.input:gsub("\n", "\\n"):gsub("\t", "\\t")))

    -- Simulate formatSelectionSeed flow
    local leading_ws = test.input:match("^(%s*)") or ""
    local trailing_ws = test.input:match("(%s*)$") or ""
    local body = test.input:sub(1, #test.input - #trailing_ws)
    local prefix, seed = strings.extractSeed(body)

    print(string.format("Extracted seed: '%s'", seed:gsub("\n", "\\n")))

    local context = {}
    local matched, matchedId = registry:process(seed, context)

    local arithmeticMatched = (matchedId == "arithmetic")
    local navigationMatched = (context.__lastSideEffect ~= nil and context.__lastSideEffect.type == "kagi_search")

    -- Check if results match expectations
    local arithmeticPass = arithmeticMatched == test.shouldMatchArithmetic
    local navigationPass = (not test.shouldMatchNavigation and not navigationMatched) or (test.shouldMatchNavigation and navigationMatched)

    if arithmeticPass and navigationPass then
        print(string.format("✓ PASS - Matched: %s", tostring(matchedId)))
        if context.__lastSideEffect then
            print(string.format("  Side effect: %s", context.__lastSideEffect.type))
        end
        passCount = passCount + 1
    else
        print(string.format("✗ FAIL"))
        print(string.format("  Expected arithmetic: %s, got: %s", tostring(test.shouldMatchArithmetic), tostring(arithmeticMatched)))
        print(string.format("  Expected navigation: %s, got: %s", tostring(test.shouldMatchNavigation), tostring(navigationMatched)))
        failCount = failCount + 1
    end
    print()
end

print(string.format("=== Results: %d passed, %d failed ===", passCount, failCount))

if failCount > 0 then
    os.exit(1)
end
