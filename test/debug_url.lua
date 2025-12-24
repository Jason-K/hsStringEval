#!/usr/bin/env lua

-- Quick debug for URL case
local helper = require("spec_helper")
local strings = helper.requireFresh("utils.strings")
local RegistryFactory = helper.requireFresh("detectors.registry")
local NavigationConstructor = helper.requireFresh("detectors.navigation")

local logger = {
    d = function(msg) print(msg) end,
    e = function(msg) end,
    w = function(msg) end,
}

local navDetector = NavigationConstructor({ logger = logger })
local registry = RegistryFactory.new(logger)
registry:register(navDetector)

local url = "https://example.com"
print("Testing URL:", url)
local context = {}
local result = navDetector.match(url, context)
print("Result:", tostring(result))
if type(result) == "table" then
    print("Side effect type:", result.sideEffectOnly and "side effect only" or "normal")
    print("Output:", result.output)
end
