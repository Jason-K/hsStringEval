--[[
String processing utilities

Common string manipulation functions used across detectors and formatters.
]]

local M = {}

--[[
Normalize localized numbers to standard format

Handles various decimal separators and thousand separators.
@param input string number with potential locale formatting
@return string normalized number string
]]
function M.normalizeLocalizedNumber(input)
    if type(input) ~= "string" then return input end

    -- Remove thousand separators (comma or dot followed by 3 digits)
    local normalized = input:gsub(",(%d%d%d)", "%1")
    normalized = normalized:gsub("%.(%d%d%d)", "%1")

    -- Handle decimal comma (European style)
    if normalized:match(",") and not normalized:match("%.") then
        normalized = normalized:gsub(",", ".")
    end

    return normalized
end

--[[
URL encode a string

Simple URL encoding for navigation links.
@param str string to encode
@return string URL-encoded string
]]
function M.urlEncode(str)
    if type(str) ~= "string" then return str end

    local result = {}
    for i = 1, #str do
        local c = str:sub(i, i)
        if c == " " then
            table.insert(result, "+")
        elseif c:match("[-%w_.~]") then  -- - at start, . and ~ are literals in class
            table.insert(result, c)
        else
            table.insert(result, string.format("%%%02X", string.byte(c)))
        end
    end
    return table.concat(result)
end

--[[
Extract last expression from clipboard content

Looks for expressions after =, :, or whitespace boundaries.
Used for seed formatting.
@param content string clipboard content
@return string|nil extracted expression or nil
]]
function M.extractExpression(content)
    if type(content) ~= "string" then return nil end
    if content == "" then return "" end

    -- Try = first (e.g., "= 1 + 2")
    local expr = content:match("=%s*(.+)$")
    if expr then return expr end

    -- Try : (e.g., ":foo bar") - find LAST colon and extract after it
    local lastColonStart = content:match("^.*():")
    if lastColonStart then
        expr = content:sub(lastColonStart + 1):match("^%s*(.+)$")
        if expr then return expr end
    end

    -- Try whitespace boundary - get last non-whitespace sequence
    local lastSpace = content:match("%S+$")
    if lastSpace then return lastSpace end

    -- Whitespace-only or no match: return empty string
    return ""
end

--[[
Trim whitespace from both ends of string

@param str string to trim
@return string trimmed string
]]
function M.trim(str)
    if type(str) ~= "string" then return str end

    return str:match("^%s*(.-)%s*$")
end

return M
