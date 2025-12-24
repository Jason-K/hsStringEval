#!/usr/bin/env lua
-- Debug the extractSeed issue
local helper = require("spec_helper")
local strings = helper.requireFresh("utils.strings")

local testInput = "let x = 5 + 3"
print("Input:", testInput)
local prefix, seed = strings.extractSeed(testInput)
print("Prefix:", prefix)
print("Seed:", seed)
print()
print("Expected:")
print("  Prefix: 'let x = '")
print("  Seed: '5 + 3'")
