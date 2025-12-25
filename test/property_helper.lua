-- Property-Based Testing Helper for ClipboardFormatter
-- Provides generators and property testing utilities

local M = {}

-- Random seed for reproducibility
M.seed = os.time()

--- Set the random seed for reproducibility
-- @param seed Optional seed value (defaults to current time)
function M.setSeed(seed)
    M.seed = seed or os.time()
    math.randomseed(M.seed)
    return M.seed
end

--- Generate a random integer
-- @param min Minimum value (inclusive)
-- @param max Maximum value (inclusive)
-- @return Random integer
function M.int(min, max)
    min = min or 0
    max = max or 100
    return math.random(min, max)
end

--- Generate a random float
-- @param min Minimum value
-- @param max Maximum value
-- @return Random float
function M.float(min, max)
    min = min or 0
    max = max or 1
    return min + math.random() * (max - min)
end

--- Generate a random string
-- @param length Length of string (default random 1-20)
-- @param charset Optional character set
-- @return Random string
function M.string(length, charset)
    charset = charset or "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
    local len = length or M.int(1, 20)
    local result = {}
    for i = 1, len do
        local pos = M.int(1, #charset)
        table.insert(result, charset:sub(pos, pos))
    end
    return table.concat(result)
end

--- Generate a random alphanumeric string
-- @param length Length of string
-- @return Random alphanumeric string
function M.alnum(length)
    return M.string(length, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
end

--- Generate a random digit string
-- @param length Length of string
-- @return Random digit string
function M.digits(length)
    return M.string(length, "0123456789")
end

--- Generate a random arithmetic expression
-- @param complexity Maximum complexity (1=simple, 2=medium, 3=complex)
-- @return Random arithmetic expression string
function M.arithmeticExpr(complexity)
    complexity = complexity or 1
    local ops = { "+", "-", "*" }

    if complexity == 1 then
        -- Simple: a + b
        local a = M.int(0, 100)
        local b = M.int(0, 100)
        local op = ops[M.int(1, #ops)]
        return a .. op .. b
    elseif complexity == 2 then
        -- Medium: a + b - c
        local a = M.int(0, 50)
        local b = M.int(0, 50)
        local c = M.int(0, 50)
        return a .. " + " .. b .. " - " .. c
    else
        -- Complex: (a + b) * c
        local a = M.int(0, 20)
        local b = M.int(0, 20)
        local c = M.int(0, 10)
        return "(" .. a .. " + " .. b .. ") * " .. c
    end
end

--- Generate a random date string
-- @return Random date string in YYYY-MM-DD format
function M.dateString()
    local year = M.int(2000, 2030)
    local month = M.int(1, 12)
    local day = M.int(1, 28)
    return string.format("%04d-%02d-%02d", year, month, day)
end

--- Generate a random phone number
-- @return Random phone number string
function M.phoneNumber()
    local area = M.int(200, 999)
    local prefix = M.int(200, 999)
    local line = M.int(1000, 9999)
    return string.format("(%03d) %03d-%04d", area, prefix, line)
end

--- Generate a random percentage
-- @return Random percentage string (e.g., "25%")
function M.percentage()
    local value = M.int(0, 100)
    return value .. "%"
end

--- Generate a random currency amount
-- @return Random currency string (e.g., "$123.45")
function M.currency()
    local dollars = M.int(0, 1000)
    local cents = M.int(0, 99)
    return string.format("$%d.%02d", dollars, cents)
end

--- Generate a random element from a table
-- @param tbl Table to choose from
-- @return Random element from the table
function M.oneOf(tbl)
    if type(tbl) ~= "table" or #tbl == 0 then
        return nil
    end
    return tbl[M.int(1, #tbl)]
end

--- Generate a random subset of a table
-- @param tbl Source table
-- @param minSize Minimum subset size
-- @param maxSize Maximum subset size
-- @return Random subset of the table
function M.subset(tbl, minSize, maxSize)
    if type(tbl) ~= "table" then
        return {}
    end
    minSize = minSize or 0
    maxSize = maxSize or #tbl
    local size = M.int(minSize, math.min(maxSize, #tbl))
    local result = {}
    local indices = {}
    for i = 1, size do
        local idx
        repeat
            idx = M.int(1, #tbl)
        until not indices[idx]
        indices[idx] = true
        table.insert(result, tbl[idx])
    end
    return result
end

--- Generate a random boolean
-- @return Random boolean value
function M.boolean()
    return M.int(1, 2) == 1
end

--- Property: Run a test with many random inputs
-- @param property Property function that takes input and returns boolean
-- @param generator Function to generate random inputs
-- @param iterations Number of iterations (default 100)
-- @return success, failCount, failureInput
function M.forAll(property, generator, iterations)
    iterations = iterations or 100
    local failCount = 0
    local failureInput = nil

    for i = 1, iterations do
        local input = generator(i)
        local ok, result = pcall(property, input)
        if not ok or not result then
            failCount = failCount + 1
            failureInput = input
            if not ok then
                return false, failCount, input, result
            end
        end
    end

    return failCount == 0, failCount, failureInput
end

--- Shrink a failing input to a minimal counterexample
-- @param input The failing input
-- @param property Property function
-- @param shrinkFn Function to shrink input
-- @return Minimal failing input
function M.shrink(input, property, shrinkFn)
    local current = input
    local attempts = 0
    local maxAttempts = 100

    while attempts < maxAttempts do
        attempts = attempts + 1
        local smaller = shrinkFn(current)
        if not smaller or smaller == current then
            break
        end
        local ok, result = pcall(property, smaller)
        if not ok or not result then
            current = smaller
        else
            break
        end
    end

    return current
end

--- Run a property test with shrinking
-- @param name Test name
-- @param property Property function
-- @param generator Input generator
-- @param iterations Number of iterations
-- @return success, failCount, failureInput
function M.property(name, property, generator, iterations)
    local success, failCount, failureInput, error = M.forAll(property, generator, iterations)

    if not success then
        if error then
            return false, failCount, failureInput, error
        end
        return false, failCount, failureInput
    end

    return true, 0, nil
end

--- Generate random whitespace
-- @param maxLength Maximum length
-- @return Random whitespace string
function M.whitespace(maxLength)
    maxLength = maxLength or 10
    local chars = " \t\n\r"
    local len = M.int(0, maxLength)
    local result = {}
    for i = 1, len do
        table.insert(result, chars:sub(M.int(1, #chars), M.int(1, #chars)))
    end
    return table.concat(result)
end

--- Generate a string with leading/trailing whitespace
-- @param content Content to wrap
-- @return String with random leading/trailing whitespace
function M.wrappedString(content)
    local leading = M.whitespace(5)
    local trailing = M.whitespace(5)
    return leading .. (content or "") .. trailing
end

--- Generate a random seed format (e.g., "= 42", ": 100")
-- @param value Value to put after seed
-- @return Seed format string
function M.seedFormat(value)
    local separators = { "=", ":" }
    local sep = separators[M.int(1, #separators)]
    return sep .. " " .. (value or M.int(0, 100))
end

--- Generate edge case values for a type
-- @param typeName Type name: "int", "float", "string", "arithmetic", etc.
-- @return Table of edge case values
function M.edgeCases(typeName)
    local cases = {
        int = { 0, -1, 1, -100, 100, 1000000, -1000000, math.maxinteger, math.mininteger },
        float = { 0.0, -0.0, 0.1, -0.1, 1.5, -1.5, math.pi, -math.pi, 1/0, -1/0, 0/0 },
        string = { "", " ", "a", "a b c", "  leading", "trailing  ", "  both  ", "\t\t\n\n" },
        arithmetic = { "0", "1+1", "1-1", "2*3", "10/2", "1+2+3", "(1+2)*3" },
        percentage = { "0%", "1%", "50%", "99%", "100%" },
        currency = { "$0", "$0.01", "$1", "$100", "$1000.00" },
    }
    return cases[typeName] or {}
end

return M
