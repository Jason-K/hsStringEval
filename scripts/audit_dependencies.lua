#!/usr/bin/env lua5.4
-- Audit dependencies across all detectors and formatters
local lfs = require("lfs")
local inspect = require("inspect")

local function scanFile(filePath)
    local file = io.open(filePath, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()

    -- Extract declared dependencies
    local declared = content:match('dependencies%s*=%s*{([^}]+)}')
    local declaredList = {}
    if declared then
        for dep in declared:gmatch('"([^"]+)"') do
            table.insert(declaredList, dep)
        end
    end

    -- Extract actual usage patterns (context.XXX, deps.XXX)
    local actualUsage = {}
    for usage in content:gmatch('(%w+%.%w+)') do
        local prefix, key = usage:match('^(%w+)%.(%w+)$')
        if prefix == "context" or prefix == "deps" then
            actualUsage[key] = (actualUsage[key] or 0) + 1
        end
    end

    return {
        declared = declaredList,
        actual = actualUsage
    }
end

local function scanDirectory(dir)
    local results = {}
    for file in lfs.dir(dir) do
        if file:match("%.lua$") and file ~= "init.lua" then
            local path = dir .. "/" .. file
            local data = scanFile(path)
            if data then
                results[file] = data
            end
        end
    end
    return results
end

print("=== Dependency Audit ===\n")

print("## Detectors")
local detectors = scanDirectory("src/detectors")
for name, data in pairs(detectors) do
    print(string.format("\n### %s", name:gsub("%.lua$", "")))
    print("Declared: " .. inspect(data.declared))
    print("Used: " .. inspect(data.actual))
end

print("\n## Formatters")
local formatters = scanDirectory("src/formatters")
for name, data in pairs(formatters) do
    print(string.format("\n### %s", name:gsub("%.lua$", "")))
    print("Declared: " .. inspect(data.declared))
    print("Used: " .. inspect(data.actual))
end
