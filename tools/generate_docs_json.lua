#!/usr/bin/env lua
--[[
Generate docs.json for ClipboardFormatter from Hammerspoon-style docstrings in src/init.lua.

USAGE:
    lua tools/generate_docs_json.lua

OUTPUT:
    docs.json at the project root (used by EmmyLua.spoon for LSP autocomplete).
]]

-- ============================================================================
-- JSON encoder (no external deps)
-- ============================================================================
local function encodeJson(val, indent)
    indent = indent or 0
    local ind  = string.rep("  ", indent)
    local ind1 = string.rep("  ", indent + 1)
    if type(val) == "table" then
        if #val > 0 then
            local parts = {}
            for _, v in ipairs(val) do
                table.insert(parts, ind1 .. encodeJson(v, indent + 1))
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, ind1 .. '"' .. tostring(k) .. '": ' .. encodeJson(v, indent + 1))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
        end
    elseif type(val) == "string" then
        local e = val:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')
        return '"' .. e .. '"'
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "number" then
        return tostring(val)
    else
        return "null"
    end
end

-- ============================================================================
-- Docstring parser
-- ============================================================================
-- Parses consecutive `--- ` lines starting at startLine.
-- Returns { def, type, doc } or nil.
local function parseBlock(lines, startLine)
    if not (lines[startLine] and lines[startLine]:match("^%-%-%- ")) then
        return nil
    end

    local raw = {}
    local i = startLine
    while lines[i] and lines[i]:match("^%-%-%-") do
        -- strip leading "--- " or "---"
        table.insert(raw, (lines[i]:gsub("^%-%-%- ?", "")))
        i = i + 1
    end

    if #raw < 2 then return nil end

    local def      = raw[1]  -- e.g. "ClipboardFormatter:init(opts) -> self"
    local itemType = raw[2]  -- e.g. "Method"

    -- Must be a known item type to qualify (Lua patterns don't support | alternation)
    local validTypes = { Method = true, Function = true, Variable = true, Constant = true }
    if not validTypes[itemType] then
        return nil
    end

    local docParts = {}
    for j = 3, #raw do
        table.insert(docParts, raw[j])
    end

    return {
        def      = def,
        type     = itemType,
        doc      = table.concat(docParts, "\n"),
    }
end

-- ============================================================================
-- Main
-- ============================================================================
local scriptDir = (debug.getinfo(1,"S").source:match("^@(.*/)" ) or "./")
local srcFile   = scriptDir .. "../src/init.lua"
local outFile   = scriptDir .. "../docs.json"

local fh = io.open(srcFile, "r")
if not fh then
    io.stderr:write("ERROR: cannot open " .. srcFile .. "\n")
    os.exit(1)
end

local lines = {}
for line in fh:lines() do
    table.insert(lines, line)
end
fh:close()

local items = {}
for i = 1, #lines do
    local block = parseBlock(lines, i)
    if block then
        table.insert(items, block)
    end
end

if #items == 0 then
    io.stderr:write("WARNING: no docstring blocks found in " .. srcFile .. "\n")
end

local output = encodeJson({ { items = items } }, 0)

local out = io.open(outFile, "w")
if not out then
    io.stderr:write("ERROR: cannot write " .. outFile .. "\n")
    os.exit(1)
end
out:write(output .. "\n")
out:close()

print(string.format("Wrote %d items to %s", #items, outFile))
