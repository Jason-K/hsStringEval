local pkgRoot = (...):match("^(.*)%.formatters%.arithmetic$")
local strings = require(pkgRoot .. ".utils.strings")
local currency = require(pkgRoot .. ".formatters.currency")
local patterns = require(pkgRoot .. ".utils.patterns")

local Arithmetic = {}

local function getPatternEntry(opts, name)
    if opts and opts.patterns then
        local entry = opts.patterns[name]
        if type(entry) == "table" and type(entry.match) == "function" then
            return entry
        end
    end
    return patterns.compiled(name)
end

local function normalizeNumberToken(token, opts)
    if type(token) ~= "string" then
        return token
    end
    local normalized = strings.normalizeMinus(token)
    normalized = normalized:gsub("%$", "")
    normalized = normalized:gsub("%s+", "")
    if normalized == "" then
        return normalized
    end
    local sign = ""
    local firstChar = normalized:sub(1, 1)
    if firstChar == "+" or firstChar == "-" then
        sign = firstChar
        normalized = normalized:sub(2)
    end
    local localizedPattern = getPatternEntry(opts, "localized_number")
    if localizedPattern then
        local match = localizedPattern.match(sign .. normalized) or localizedPattern.match(normalized)
        if match then
            local lastComma = normalized:match(".*(),")
            local lastDot = normalized:match(".*()%.")
            if lastComma and lastDot then
                if lastComma > lastDot then
                    normalized = normalized:gsub("%.", "")
                    normalized = normalized:gsub(",", ".")
                else
                    normalized = normalized:gsub(",", "")
                end
            elseif lastComma then
                local digitsAfter = #normalized - lastComma
                if digitsAfter ~= 3 then
                    normalized = normalized:gsub(",", ".")
                else
                    normalized = normalized:gsub(",", "")
                end
            end
        end
    end
    normalized = normalized:gsub(",", "")
    return sign .. normalized
end

local function normalizeExpressionNumbers(expression, opts)
    return (expression:gsub("([%+%-]?[%d%.,]+)", function(token)
        local replacement = normalizeNumberToken(token, opts)
        if type(replacement) ~= "string" or replacement == "" then
            return token
        end
        return replacement
    end))
end

local function removeCurrencyAndWhitespace(str)
    return (str or ""):gsub("%$", ""):gsub("%s+", "")
end

local function tokenizeExpression(equation)
    local tokens = {}
    local currentNum = ""
    local isNegative = false
    local lastWasOperator = true

    for i = 1, #equation do
        local char = equation:sub(i, i)
        if char:match("[%d%.]") then
            -- Check for implicit multiplication: ) followed by digit
            if not lastWasOperator and #tokens > 0 and tokens[#tokens] == ")" then
                table.insert(tokens, "*")
            end
            currentNum = currentNum .. char
            lastWasOperator = false
        elseif char == "(" then
            -- Flush pending number before opening paren
            if currentNum ~= "" then
                local numeric = tonumber(currentNum)
                if numeric then
                    table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
                    table.insert(tokens, "*")  -- Implicit multiplication: number followed by (
                end
                currentNum = ""
                isNegative = false
            end
            table.insert(tokens, char)
            lastWasOperator = true
        elseif char == ")" then
            -- Flush pending number before closing paren
            if currentNum ~= "" then
                local numeric = tonumber(currentNum)
                if numeric then
                    table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
                end
                currentNum = ""
                isNegative = false
            end
            table.insert(tokens, char)
            lastWasOperator = false  -- ) acts like a number for implicit multiplication
        elseif char == "+" or char == "-" or char == "*" or char == "/" or char == "%" or char == "^" then
            if char == "-" and lastWasOperator then
                isNegative = not isNegative
            else
                if currentNum ~= "" then
                    local numeric = tonumber(currentNum)
                    if numeric then
                        table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
                    end
                    currentNum = ""
                    isNegative = false
                end
                table.insert(tokens, char)
                lastWasOperator = true
            end
        end
    end

    if currentNum ~= "" then
        local numeric = tonumber(currentNum)
        if numeric then
            table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
        end
    end

    return tokens
end

local function evaluateTokens(tokens)
    local cleanTokens = {}
    for _, token in ipairs(tokens) do
        if token ~= " " then
            table.insert(cleanTokens, token)
        end
    end

    local function isOperator(token)
        return token == "+" or token == "-" or token == "*" or token == "/" or token == "%" or token == "^"
    end

    local precedence = {
        ["^"] = 4,
        ["*"] = 3,
        ["/"] = 3,
        ["%"] = 3,
        ["+"] = 2,
        ["-"] = 2,
    }

    local rightAssociative = {
        ["^"] = true,
    }

    local output = {}
    local stack = {}

    for _, token in ipairs(cleanTokens) do
        local number = tonumber(token)
        if number ~= nil then
            table.insert(output, number)
        elseif token == "(" then
            table.insert(stack, token)
        elseif token == ")" then
            while #stack > 0 and stack[#stack] ~= "(" do
                table.insert(output, table.remove(stack))
            end
            if #stack > 0 and stack[#stack] == "(" then
                table.remove(stack)
            end
        elseif isOperator(token) then
            while true do
                local top = stack[#stack]
                if not top or not isOperator(top) then
                    break
                end
                local currentPrecedence = precedence[token] or 0
                local topPrecedence = precedence[top] or 0
                local isRightAssociative = rightAssociative[token] == true
                local shouldPop = currentPrecedence < topPrecedence
                    or (not isRightAssociative and currentPrecedence == topPrecedence)
                if shouldPop then
                    table.insert(output, table.remove(stack))
                else
                    break
                end
            end
            table.insert(stack, token)
        end
    end

    while #stack > 0 do
        table.insert(output, table.remove(stack))
    end

    local eval = {}
    for _, token in ipairs(output) do
        if type(token) == "number" then
            table.insert(eval, token)
        elseif isOperator(token) then
            local b = table.remove(eval)
            local a = table.remove(eval)
            if a == nil or b == nil then
                return nil
            end
            local result
            if token == "+" then
                result = a + b
            elseif token == "-" then
                result = a - b
            elseif token == "*" then
                result = a * b
            elseif token == "/" then
                if b == 0 then return nil end
                result = a / b
            elseif token == "%" then
                if b == 0 then return nil end
                result = a % b
            elseif token == "^" then
                result = a ^ b
            end
            table.insert(eval, result)
        else
            return nil
        end
    end

    if #eval ~= 1 then
        return nil
    end

    return eval[1]
end


function Arithmetic.isCandidate(content, opts)
    if not content or content == "" then return false end
    local normalized = strings.normalizeMinus(content)
    local trimmed = strings.trim(normalized)
    if trimmed == "" then return false end
    local datePattern = getPatternEntry(opts, "date_full")
    if datePattern and datePattern.match(trimmed) == trimmed then
        return false
    end
    local arithmeticPattern = getPatternEntry(opts, "arithmetic_candidate")
    if arithmeticPattern and arithmeticPattern.match(trimmed) == nil then
        return false
    end
    local stripped = normalizeExpressionNumbers(removeCurrencyAndWhitespace(trimmed), opts)
    if stripped == "" then return false end
    if stripped:find("[^%d%.%(%)%+%-%*/%%^]") then
        return false
    end
    return true
end

function Arithmetic.process(content, opts)
    if not Arithmetic.isCandidate(content, opts) then
        return nil
    end

    local hasCurrency = content:find("%$") ~= nil
    local normalized = strings.normalizeMinus(content)
    local displayInput = strings.trim(normalized)
    local cleaned = normalizeExpressionNumbers(removeCurrencyAndWhitespace(normalized), opts)

    -- Use tokenizer for all expressions (now supports parentheses)
    local tokens = tokenizeExpression(cleaned)
    local result = evaluateTokens(tokens)

    if not result then
        return nil
    end

    local numericResult = result
    local formattedResult
    if hasCurrency then
        formattedResult = currency.format(numericResult)
        if not formattedResult then
            return nil
        end
    else
        if type(numericResult) == "number" then
            local integral = math.floor(numericResult)
            if math.abs(numericResult - integral) < 1e-9 then
                formattedResult = tostring(integral)
            else
                formattedResult = tostring(numericResult)
            end
        else
            formattedResult = tostring(numericResult)
        end
    end

    local template
    if opts and opts.config and opts.config.templates then
        template = opts.config.templates.arithmetic
    end
    if template and template ~= "" then
        local replacements = {
            input = displayInput,
            result = formattedResult,
            numeric = tostring(numericResult),
        }
        local rendered = template:gsub("%${(.-)}", function(key)
            return replacements[key] or ""
        end)
        return rendered
    end

    return formattedResult
end

return Arithmetic
