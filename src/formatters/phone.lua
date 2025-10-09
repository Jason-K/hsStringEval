local Phone = {}

local pkgRoot = (...):match("^(.*)%.formatters%.phone$")
local patterns = require(pkgRoot .. ".utils.patterns")

local function getPatternEntry(opts, name)
    if opts and opts.patterns then
        local entry = opts.patterns[name]
        if type(entry) == "table" and type(entry.match) == "function" then
            return entry
        end
    end
    return patterns.compiled(name)
end

function Phone.isCandidate(content, opts)
    if not content then return false end
    local pattern = getPatternEntry(opts, "phone_semicolon")
    if pattern and pattern.contains then
        return pattern.contains(content)
    end
    return content:find(";") ~= nil
end

function Phone.format(content, _opts)
    local fields = {}
    for field in content:gmatch("([^;]+)") do
        table.insert(fields, field)
    end
    if #fields < 2 then return nil end
    local digits = fields[1]:gsub("%D", "")
    if #digits ~= 10 then return nil end
    local formatted = string.format("(%s) %s-%s", digits:sub(1, 3), digits:sub(4, 6), digits:sub(7, 10))
    for i = 2, #fields do
        formatted = formatted .. ",,," .. fields[i]
    end
    return formatted
end

return Phone
