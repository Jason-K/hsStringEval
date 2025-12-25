local pkgRoot = (...):match("^(.*)%.utils%.clipboard_operations$")
local hsUtils = require(pkgRoot .. ".utils.hammerspoon")

local ClipboardOperations = {}

-- Default configuration for retry logic
local DEFAULT_RETRY_CONFIG = {
    maxRetries = 3,
    baseDelayMs = 100,
    maxDelayMs = 2000,
    jitterMs = 50,
    exponentialBackoff = true,
}

-- Deep copy function
local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Sleep function (cross-platform)
local function sleep(ms)
    hsUtils.sleep(ms)
end

-- Calculate delay with exponential backoff and jitter
local function calculateDelay(attempt, config)
    local delay
    if config.exponentialBackoff then
        delay = config.baseDelayMs * (2 ^ (attempt - 1))
    else
        delay = config.baseDelayMs
    end

    -- Cap at maximum delay
    delay = math.min(delay, config.maxDelayMs)

    -- Add jitter to avoid thundering herd (safely handle nil config.jitterMs)
    local jitterMs = config.jitterMs or DEFAULT_RETRY_CONFIG.jitterMs
    local jitter = math.random(0, jitterMs or 0)
    return delay + jitter
end

-- Execute function with retry logic
local function executeWithRetry(operationFn, operationName, config, logger)
    local maxAttempts = config.maxRetries or DEFAULT_RETRY_CONFIG.maxRetries
    local lastError = nil

    for attempt = 1, maxAttempts do
        local success, result = pcall(operationFn)

        if success and result then
            -- On success, log if not first attempt
            if attempt > 1 and logger and logger.d then
                logger.d(("%s succeeded on attempt %d"):format(operationName, attempt))
            end
            return result
        end

        lastError = result or ("Unknown error on attempt %d"):format(attempt)

        if attempt < maxAttempts then
            local delay = calculateDelay(attempt, config)
            if logger and logger.w then
                logger.w(("%s failed (attempt %d/%d): %s, retrying in %dms"):format(
                    operationName, attempt, maxAttempts, tostring(lastError), delay))
            end

            -- Use appropriate sleep method
            sleep(delay)
        end
    end

    -- All attempts failed
    if logger and logger.e then
        logger.e(("%s failed after %d attempts: %s"):format(
            operationName, maxAttempts, tostring(lastError)))
    end

    return nil
end

-- Enhanced clipboard read with retry logic
function ClipboardOperations.getTextWithRetry(config, logger)
    config = config or {}
    local retryConfig = config.retry or {}

    return executeWithRetry(function()
        -- Try multiple methods in order
        local content

        -- Method 1: Primary pasteboard
        if hsUtils.hasPasteboard() then
            content = hsUtils.getPasteboard()
            if type(content) == "string" and content ~= "" then
                return content
            end
        end

        -- Method 2: Find pasteboard
        if hsUtils.hasPasteboard() then
            content = hsUtils.getPasteboard("find")
            if type(content) == "string" and content ~= "" then
                return content
            end
        end

        -- Method 3: AppleScript fallback
        content = hsUtils.readClipboardFallback()
        if type(content) == "string" and content ~= "" then
            return content
        end

        -- Method 4: Accessibility API (if available)
        -- Note: This would require hs.uielement which may not be available in all contexts
        -- For now, skip this method as it's not exposed through hammerspoon utils

        return nil -- All methods failed
    end, "clipboard read", retryConfig, logger)
end

-- Enhanced clipboard write with retry logic
function ClipboardOperations.setTextWithRetry(text, config, logger)
    if not text or text == "" then
        return false
    end

    config = config or {}
    local retryConfig = config.retry or {}

    return executeWithRetry(function()
        -- Try multiple write methods

        -- Method 1: Direct pasteboard write
        if hsUtils.hasPasteboard() then
            local ok, err = pcall(hsUtils.setPasteboard, text)
            if ok then
                -- Verify the write succeeded
                local verify = hsUtils.getPasteboard()
                if verify == text then
                    return true
                end
            elseif logger and logger.w then
                logger.w("Direct pasteboard write failed: " .. tostring(err))
            end
        end

        -- Method 2: AppleScript fallback
        local ok, result = pcall(hsUtils.writeClipboardFallback, text)
        if ok and result then
            return true
        elseif logger and logger.w then
            logger.w("AppleScript write failed: " .. tostring(result))
        end

        return false
    end, "clipboard write", retryConfig, logger) or false
end

-- Clear clipboard with retry logic
function ClipboardOperations.clearWithRetry(config, logger)
    config = config or {}
    local retryConfig = config.retry or {}

    return executeWithRetry(function()
        if hsUtils.hasPasteboard() then
            local ok, err = pcall(hsUtils.clearPasteboard)
            if ok then
                return true
            elseif logger and logger.w then
                logger.w("Clear pasteboard failed: " .. tostring(err))
            end
        end
        return false
    end, "clipboard clear", retryConfig, logger) or false
end

-- Test clipboard functionality and return status
function ClipboardOperations.testClipboardOperations(config, logger)
    local testText = "ClipboardTest_" .. os.time()
    local results = {
        canRead = false,
        canWrite = false,
        canClear = false,
        errors = {}
    }

    -- Test write
    if ClipboardOperations.setTextWithRetry(testText, config, logger) then
        results.canWrite = true

        -- Test read
        local read = ClipboardOperations.getTextWithRetry(config, logger)
        if read == testText then
            results.canRead = true
        else
            table.insert(results.errors, "Write succeeded but read verification failed")
        end

        -- Test clear
        if ClipboardOperations.clearWithRetry(config, logger) then
            results.canClear = true
        else
            table.insert(results.errors, "Clear operation failed")
        end
    else
        table.insert(results.errors, "Write operation failed")
    end

    return results
end

-- Get clipboard operation statistics (for monitoring)
function ClipboardOperations.getStats()
    -- This could be expanded to track success rates, timing, etc.
    return {
        operationsSupported = {
            pasteboard = hsUtils.hasPasteboard(),
            timer = hsUtils.hasTimer ~= nil, -- hasTimer exists as internal helper
            applescript = true -- Always available as fallback
        }
    }
end

-- Create default configuration with retry settings
function ClipboardOperations.createConfig(overrides)
    local config = deepCopy(DEFAULT_RETRY_CONFIG)

    if overrides then
        for key, value in pairs(overrides) do
            config[key] = value
        end
    end

    return config
end

return ClipboardOperations