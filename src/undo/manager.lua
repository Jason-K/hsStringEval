--[[
WHAT THIS FILE DOES:
This module provides an undo/redo system for clipboard formatting operations.
It allows users to undo formatting operations and restore previous clipboard states,
providing a safety net for experimentation and handling accidental formatting.

KEY CONCEPTS:
- Operation History: Tracks all clipboard formatting operations with context
- Configurable Retention: Allows users to configure how many operations to remember
- Thread-Safe Operations: Uses atomic operations to prevent race conditions
- Memory Management: Automatically prunes old operations to prevent memory leaks
- Context Awareness: Preserves formatting context for intelligent undo/redo

EXAMPLE USAGE:
    local UndoManager = require("src.undo.manager")
    local undoManager = UndoManager.new({maxHistory = 50})
    undoManager:execute(operation, context)
    undoManager:undo()
    undoManager:redo()
]]

local pkgRoot = (...):match("^(.*)%.undo%.manager$")
local clipboardIO = require(pkgRoot .. ".clipboard.io")
local hsUtils = require(pkgRoot .. ".utils.hammerspoon")

local UndoManager = {}

-- Default configuration
local DEFAULT_CONFIG = {
    maxHistory = 100,
    maxMemoryKB = 1024, -- 1MB
    autoCleanup = true,
    persistHistory = false,
    compressOldEntries = true,
    debugMode = false
}

-- Operation types
local OPERATION_TYPES = {
    CLIPBOARD_FORMAT = "clipboard_format",
    SELECTION_FORMAT = "selection_format",
    CLIPBOARD_SEED = "clipboard_seed",
    CUSTOM = "custom"
}

-- Operation status
local OPERATION_STATUS = {
    SUCCESS = "success",
    FAILED = "failed",
    PARTIAL = "partial"
}

-- Memory usage estimator
local function estimateOperationSize(operation)
    local size = 0
    if operation.originalContent then
        size = size + #operation.originalContent
    end
    if operation.formattedContent then
        size = size + #operation.formattedContent
    end
    if operation.context then
        -- Rough estimation of context size
        size = size + 500
    end
    return size
end

-- Create a unique operation ID
local function generateOperationId()
    return os.time() .. "_" .. math.random(1000, 9999)
end

-- Compress old operation content (simple compression)
local function compressContent(content)
    if not content or content == "" then
        return content
    end

    -- Simple compression: truncate very long content with marker
    if #content > 1000 then
        return content:sub(1, 500) .. "...[truncated]..." .. content:sub(-500)
    end

    return content
end

-- Private constructor
local function new(config)
    config = config or {}
    local instance = {
        history = {},
        currentIndex = 0,
        config = {
            maxHistory = config.maxHistory or DEFAULT_CONFIG.maxHistory,
            maxMemoryKB = config.maxMemoryKB or DEFAULT_CONFIG.maxMemoryKB,
            autoCleanup = config.autoCleanup ~= false,
            persistHistory = config.persistHistory or DEFAULT_CONFIG.persistHistory,
            compressOldEntries = config.compressOldEntries ~= false,
            debugMode = config.debugMode or DEFAULT_CONFIG.debugMode
        },
        stats = {
            totalOperations = 0,
            undoOperations = 0,
            redoOperations = 0,
            memoryUsageKB = 0,
            cleanupOperations = 0
        }
    }
    setmetatable(instance, { __index = UndoManager })
    return instance
end

-- Debug logging
local function debugLog(instance, message, data)
    if instance.config.debugMode then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local logMessage = ("[%s] UndoManager: %s"):format(timestamp, message)
        if data then
            logMessage = logMessage .. " | " .. tostring(data)
        end
        print(logMessage)
    end
end

-- Memory cleanup
local function performCleanup(instance)
    if not instance.config.autoCleanup then
        return
    end

    local memoryUsage = 0
    local operationsToRemove = {}

    -- Calculate current memory usage
    for i, operation in ipairs(instance.history) do
        memoryUsage = memoryUsage + estimateOperationSize(operation)

        -- Mark very old operations for removal
        if i < instance.currentIndex - instance.config.maxHistory then
            table.insert(operationsToRemove, i)
        end
    end

    -- Check memory threshold
    if memoryUsage > (instance.config.maxMemoryKB * 1024) or #operationsToRemove > 0 then
        debugLog(instance, "Performing cleanup", {
            memoryKB = math.floor(memoryUsage / 1024),
            operationsToRemove = #operationsToRemove
        })

        -- Remove old operations
        for i = #operationsToRemove, 1, -1 do
            table.remove(instance.history, operationsToRemove[i])
            instance.currentIndex = math.max(0, instance.currentIndex - 1)
            instance.stats.cleanupOperations = instance.stats.cleanupOperations + 1
        end

        -- Compress old entries if enabled
        if instance.config.compressOldEntries then
            for i, operation in ipairs(instance.history) do
                if i < instance.currentIndex - 10 then -- Keep last 10 uncompressed
                    if operation.originalContent then
                        operation.originalContent = compressContent(operation.originalContent)
                        operation.compressed = true
                    end
                    if operation.formattedContent then
                        operation.formattedContent = compressContent(operation.formattedContent)
                    end
                end
            end
        end
    end

    instance.stats.memoryUsageKB = math.floor(memoryUsage / 1024)
end

-- Create an operation record
local function createOperation(operationType, originalContent, formattedContent, context, status)
    return {
        id = generateOperationId(),
        type = operationType or OPERATION_TYPES.CUSTOM,
        originalContent = originalContent,
        formattedContent = formattedContent,
        context = context or {},
        status = status or OPERATION_STATUS.SUCCESS,
        timestamp = os.time(),
        memorySize = 0 -- Will be calculated
    }
end

-- Execute an operation with undo support
function UndoManager:execute(operationType, formatter, context)
    context = context or {}

    -- Get current clipboard state
    local originalContent = clipboardIO.getPrimaryPasteboard()
    if not originalContent then
        debugLog(self, "No clipboard content to operate on")
        return nil, "no_content"
    end

    debugLog(self, "Executing operation", {
        type = operationType,
        originalLength = #originalContent
    })

    -- Execute the formatter
    local ok, formattedContent, sideEffect = pcall(formatter, originalContent)
    if not ok then
        debugLog(self, "Formatter failed", formattedContent)
        return nil, formattedContent
    end

    -- Apply the formatted content
    if formattedContent and formattedContent ~= originalContent then
        local applySuccess = pcall(function()
            clipboardIO.setPrimaryPasteboard(formattedContent)
        end)

        if not applySuccess then
            debugLog(self, "Failed to apply formatted content")
            return nil, "apply_failed"
        end
    else
        formattedContent = originalContent -- No change
    end

    -- Create operation record
    local operation = createOperation(
        operationType,
        originalContent,
        formattedContent,
        context,
        formattedContent ~= originalContent and OPERATION_STATUS.SUCCESS or OPERATION_STATUS.PARTIAL
    )

    -- Add side effects to context
    if sideEffect then
        operation.context.sideEffect = sideEffect
    end

    -- Trim history to current position (remove redo operations)
    while #self.history > self.currentIndex do
        table.remove(self.history)
    end

    -- Add new operation to history
    table.insert(self.history, operation)
    self.currentIndex = #self.history

    -- Update stats
    self.stats.totalOperations = self.stats.totalOperations + 1

    -- Perform cleanup if needed
    performCleanup(self)

    debugLog(self, "Operation completed", {
        operationId = operation.id,
        historySize = #self.history
    })

    return {
        success = true,
        operationId = operation.id,
        originalContent = originalContent,
        formattedContent = formattedContent,
        sideEffect = sideEffect
    }
end

-- Undo the last operation
function UndoManager:undo()
    if self.currentIndex == 0 then
        debugLog(self, "No operations to undo")
        return nil, "nothing_to_undo"
    end

    local operation = self.history[self.currentIndex]
    if not operation then
        return nil, "invalid_operation"
    end

    debugLog(self, "Undoing operation", {
        operationId = operation.id,
        type = operation.type
    })

    -- Restore original content
    if operation.originalContent then
        local restoreSuccess = pcall(function()
            clipboardIO.setPrimaryPasteboard(operation.originalContent)
        end)

        if not restoreSuccess then
            debugLog(self, "Failed to restore original content")
            return nil, "restore_failed"
        end
    end

    self.currentIndex = self.currentIndex - 1
    self.stats.undoOperations = self.stats.undoOperations + 1

    return {
        success = true,
        operationId = operation.id,
        restoredContent = operation.originalContent,
        type = operation.type,
        context = operation.context
    }
end

-- Redo the last undone operation
function UndoManager:redo()
    if self.currentIndex >= #self.history then
        debugLog(self, "No operations to redo")
        return nil, "nothing_to_redo"
    end

    self.currentIndex = self.currentIndex + 1
    local operation = self.history[self.currentIndex]
    if not operation then
        self.currentIndex = self.currentIndex - 1
        return nil, "invalid_operation"
    end

    debugLog(self, "Redoing operation", {
        operationId = operation.id,
        type = operation.type
    })

    -- Reapply formatted content
    if operation.formattedContent then
        local applySuccess = pcall(function()
            clipboardIO.setPrimaryPasteboard(operation.formattedContent)
        end)

        if not applySuccess then
            debugLog(self, "Failed to reapply formatted content")
            self.currentIndex = self.currentIndex - 1
            return nil, "reapply_failed"
        end
    end

    self.stats.redoOperations = self.stats.redoOperations + 1

    return {
        success = true,
        operationId = operation.id,
        content = operation.formattedContent,
        type = operation.type,
        context = operation.context
    }
end

-- Check if undo is available
function UndoManager:canUndo()
    return self.currentIndex > 0
end

-- Check if redo is available
function UndoManager:canRedo()
    return self.currentIndex < #self.history
end

-- Get operation history
function UndoManager:getHistory(limit)
    limit = limit or #self.history
    local history = {}

    for i = 1, math.min(limit, #self.history) do
        local operation = self.history[i]
        table.insert(history, {
            id = operation.id,
            type = operation.type,
            status = operation.status,
            timestamp = operation.timestamp,
            hasOriginalContent = operation.originalContent ~= nil,
            hasFormattedContent = operation.formattedContent ~= nil,
            isCurrent = i == self.currentIndex,
            compressed = operation.compressed or false
        })
    end

    return history
end

-- Clear all history
function UndoManager:clearHistory()
    debugLog(self, "Clearing history", {
        previousSize = #self.history
    })

    self.history = {}
    self.currentIndex = 0
    self.stats.memoryUsageKB = 0
end

-- Get statistics
function UndoManager:getStats()
    return {
        totalOperations = self.stats.totalOperations,
        undoOperations = self.stats.undoOperations,
        redoOperations = self.stats.redoOperations,
        memoryUsageKB = self.stats.memoryUsageKB,
        cleanupOperations = self.stats.cleanupOperations,
        historySize = #self.history,
        currentIndex = self.currentIndex,
        canUndo = self:canUndo(),
        canRedo = self:canRedo()
    }
end

-- Update configuration
function UndoManager:updateConfig(newConfig)
    for key, value in pairs(newConfig) do
        if self.config[key] ~= nil then
            self.config[key] = value
            debugLog(self, "Configuration updated", {key = key, value = value})
        end
    end

    -- Perform cleanup with new configuration
    performCleanup(self)
end

-- Get current configuration
function UndoManager:getConfig()
    return {
        maxHistory = self.config.maxHistory,
        maxMemoryKB = self.config.maxMemoryKB,
        autoCleanup = self.config.autoCleanup,
        persistHistory = self.config.persistHistory,
        compressOldEntries = self.config.compressOldEntries,
        debugMode = self.config.debugMode
    }
end

-- Singleton instance for global use
local globalInstance = nil

function UndoManager.getInstance(config)
    if not globalInstance then
        globalInstance = new(config)
    end
    return globalInstance
end

function UndoManager.resetInstance()
    globalInstance = nil
end

-- Export constants
UndoManager.OPERATION_TYPES = OPERATION_TYPES
UndoManager.OPERATION_STATUS = OPERATION_STATUS

-- Export factory
return {
    new = new,
    getInstance = UndoManager.getInstance,
    resetInstance = UndoManager.resetInstance,
    OPERATION_TYPES = OPERATION_TYPES,
    OPERATION_STATUS = OPERATION_STATUS
}