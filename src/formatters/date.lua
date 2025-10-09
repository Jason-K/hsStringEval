local pkgRoot = (...):match("^(.*)%.formatters%.date$")
local strings = require(pkgRoot .. ".utils.strings")
local patterns = require(pkgRoot .. ".utils.patterns")

local Date = {}

local monthLookup = {
    january = 1, jan = 1,
    february = 2, feb = 2,
    march = 3, mar = 3,
    april = 4, apr = 4,
    may = 5,
    june = 6, jun = 6,
    july = 7, jul = 7,
    august = 8, aug = 8,
    september = 9, sep = 9, sept = 9,
    october = 10, oct = 10,
    november = 11, nov = 11,
    december = 12, dec = 12,
}

local function getPatternEntry(opts, name)
    if opts and opts.patterns then
        local entry = opts.patterns[name]
        if type(entry) == "table" and type(entry.match) == "function" then
            return entry
        end
    end
    return patterns.compiled(name)
end

local function cleanToken(token)
    local trimmed = strings.trim(token or "")
    trimmed = trimmed:gsub("^[%s,%-:%(%)]*", "")
    trimmed = trimmed:gsub("[%s,%-:%(%)]*$", "")
    return strings.trim(trimmed)
end

local function normalizeYear(y)
    y = tonumber(y)
    if not y then return nil end
    if y < 100 then
        local currentYear = tonumber(os.date("%Y")) or 2000
        local currentCentury = math.floor(currentYear / 100) * 100
        if y + currentCentury > currentYear + 30 then
            currentCentury = currentCentury - 100
        end
        return y + currentCentury
    end
    return y
end

local function validateDate(m, d, y)
    if not (m and d and y) then return false end
    m, d, y = tonumber(m), tonumber(d), tonumber(y)
    if m == nil or d == nil or y == nil then return false end
    if m < 1 or m > 12 or d < 1 or d > 31 or y < 1900 then
        return false
    end
    local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0) then
        monthDays[2] = 29
    end
    local index = math.floor(m)
    if index < 1 or index > #monthDays then return false end
    local maxDay = monthDays[index]
    return d <= maxDay
end

local function parseDateComponents(token)
    local cleaned = strings.normalizeMinus(token or "")
    cleaned = strings.trim(cleaned)
    cleaned = cleaned:gsub("[%.,]+$", "")
    cleaned = cleaned:gsub("(%d)(st|nd|rd|th)", "%1")
    if cleaned == "" then return nil end

    local isoYear, isoMonth, isoDay = cleaned:match("^(%d%d%d%d)[%-%./](%d%d)[%-%./](%d%d)")
    if isoYear then
        local monthValue = tonumber(isoMonth)
        local dayValue = tonumber(isoDay)
        local yearValue = normalizeYear(isoYear)
        if monthValue and dayValue and yearValue then
            return {
                month = monthValue,
                day = dayValue,
                year = yearValue,
                missingYear = false,
            }
        end
        return nil
    end

    local monthPart, dayPart, yearPart = cleaned:match("^(%d+)[/%.-](%d+)[/%.-](%d+)$")
    if monthPart and dayPart then
        local monthValue = tonumber(monthPart)
        local dayValue = tonumber(dayPart)
        local yearValue = normalizeYear(yearPart)
        if monthValue and dayValue and yearValue then
            return {
                month = monthValue,
                day = dayValue,
                year = yearValue,
                missingYear = false,
            }
        end
        return nil
    end

    monthPart, dayPart = cleaned:match("^(%d+)[/%.-](%d+)$")
    if monthPart and dayPart then
        local monthValue = tonumber(monthPart)
        local dayValue = tonumber(dayPart)
        if monthValue and dayValue then
            return {
                month = monthValue,
                day = dayValue,
                year = nil,
                missingYear = true,
            }
        end
        return nil
    end

    local monthName, dayToken, trailing = cleaned:match("^([%a%.]+)%s+(%d%d?)(.*)$")
    if monthName then
        local lookupKey = monthName:gsub("%.", ""):lower()
        local monthValue = monthLookup[lookupKey]
        local dayValue = tonumber(dayToken)
        if not monthValue or not dayValue then
            return nil
        end
        local yearString = trailing:match("^%s*,?%s*(%d%d%d?%d?)$")
        if yearString and yearString ~= "" then
            local yearValue = normalizeYear(yearString)
            if not yearValue then
                return nil
            end
            return {
                month = monthValue,
                day = dayValue,
                year = yearValue,
                missingYear = false,
            }
        end
        return {
            month = monthValue,
            day = dayValue,
            year = nil,
            missingYear = true,
        }
    end

    local dayToken, monthNameTail, trailingTail = cleaned:match("^(%d%d?)%s+([%a%.]+)(.*)$")
    if monthNameTail then
        local lookupKey = monthNameTail:gsub("%.", ""):lower()
        local monthValue = monthLookup[lookupKey]
        local dayValue = tonumber(dayToken)
        if not monthValue or not dayValue then
            return nil
        end
        local yearString = trailingTail:match("^%s*,?%s*(%d%d%d?%d?)$")
        if yearString and yearString ~= "" then
            local yearValue = normalizeYear(yearString)
            if not yearValue then
                return nil
            end
            return {
                month = monthValue,
                day = dayValue,
                year = yearValue,
                missingYear = false,
            }
        end
        return {
            month = monthValue,
            day = dayValue,
            year = nil,
            missingYear = true,
        }
    end

    return nil
end

local function collectDateTokens(content, opts)
    local source = strings.normalizeMinus(content or "")
    local entries = {
        getPatternEntry(opts, "date_token"),
        getPatternEntry(opts, "date_token_iso"),
        getPatternEntry(opts, "date_token_text"),
    }
    local matches = {}
    local seen = {}

    for _, entry in ipairs(entries) do
        if entry and entry.raw and entry.raw ~= "" then
            local pattern = "()(" .. entry.raw .. ")"
            for position, match in source:gmatch(pattern) do
                local cleaned = cleanToken(match)
                if cleaned ~= "" then
                    local finish = position + #match - 1
                    local key = position .. ":" .. finish
                    if not seen[key] then
                        table.insert(matches, { pos = position, value = cleaned })
                        seen[key] = true
                    end
                end
            end
        end
    end

    table.sort(matches, function(a, b)
        if a.pos == b.pos then
            return #a.value > #b.value
        end
        return a.pos < b.pos
    end)

    local tokens = {}
    for _, entry in ipairs(matches) do
        table.insert(tokens, entry.value)
    end
    return tokens
end

local function buildDateRecord(components)
    if not components or not components.year then
        return nil
    end
    if not validateDate(components.month, components.day, components.year) then
        return nil
    end
    local timestamp = os.time({
        year = components.year,
        month = components.month,
        day = components.day,
        hour = 12,
        min = 0,
        sec = 0,
        isdst = false,
    })
    if not timestamp then
        return nil
    end
    return {
        month = components.month,
        day = components.day,
        year = components.year,
        timestamp = timestamp,
    }
end

local function formatDate(date)
    return os.date("%m/%d/%Y", date.timestamp)
end

local function inclusiveDays(startDate, endDate)
    local diff = math.abs(endDate.timestamp - startDate.timestamp)
    return math.floor(diff / (24 * 60 * 60)) + 1
end

function Date.isRangeCandidate(content, opts)
    if not content or content == "" then return false end
    local tokens = collectDateTokens(content, opts)
    local valid = 0
    for _, token in ipairs(tokens) do
        if parseDateComponents(token) then
            valid = valid + 1
            if valid >= 2 then break end
        end
    end
    if valid < 2 then return false end
    local lower = content:lower()
    if lower:find(" to ", 1, true)
        or lower:find(" and ", 1, true)
        or lower:find(" through ", 1, true)
        or lower:find(" thru ", 1, true)
        or content:find("%-")
        or content:find("–")
        or content:find("—") then
        return true
    end
    return false
end

function Date.describeRange(content, opts)
    if not content then return nil end
    local tokens = collectDateTokens(content, opts)
    if #tokens < 2 then return nil end

    local parsed = {}
    for _, token in ipairs(tokens) do
        local components = parseDateComponents(token)
        if components then
            table.insert(parsed, components)
            if #parsed == 2 then break end
        end
    end
    if #parsed < 2 then return nil end

    local first = parsed[1]
    local second = parsed[2]
    local currentYear = tonumber(os.date("%Y")) or 2000

    if not first.year and second.year then
        first.year = second.year
        first.missingYear = true
    end
    if not second.year and first.year then
        second.year = first.year
        second.missingYear = true
    end
    if not first.year and not second.year then
        first.year = currentYear
        second.year = currentYear
        first.missingYear = true
        second.missingYear = true
    end

    local firstRecord = buildDateRecord(first)
    local secondRecord = buildDateRecord(second)
    if not firstRecord or not secondRecord then
        return nil
    end

    if secondRecord.timestamp < firstRecord.timestamp then
        if second.missingYear and second.year then
            second.year = second.year + 1
            secondRecord = buildDateRecord(second)
        elseif first.missingYear and first.year then
            first.year = first.year - 1
            firstRecord = buildDateRecord(first)
        end
    end

    if not firstRecord or not secondRecord then
        return nil
    end

    if secondRecord.timestamp < firstRecord.timestamp then
        firstRecord, secondRecord = secondRecord, firstRecord
    end

    local days = inclusiveDays(firstRecord, secondRecord)
    return string.format("%s to %s, %d days", formatDate(firstRecord), formatDate(secondRecord), days)
end

return Date
