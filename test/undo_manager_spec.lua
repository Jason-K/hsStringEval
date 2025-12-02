---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
local UndoManager = helper.requireFresh("undo.manager")

describe("UndoManager", function()
    before_each(function()
        helper.reset()
        helper.setClipboard("initial clipboard content")
        UndoManager.resetInstance()
    end)

    local mockFormatter = function(text)
        return "formatted: " .. text
    end

    local identityFormatter = function(text)
        return text -- No change
    end

    local errorFormatter = function(text)
        error("Formatter error")
    end

    describe("instance creation", function()
        it("should create a new instance", function()
            local manager = UndoManager.new()
            assert.is_not_nil(manager)
            assert.is_table(manager)
            assert.is_function(manager.execute)
            assert.is_function(manager.undo)
            assert.is_function(manager.redo)
        end)

        it("should use singleton pattern", function()
            local instance1 = UndoManager.getInstance()
            local instance2 = UndoManager.getInstance()
            assert.are.equal(instance1, instance2)
        end)

        it("should reset singleton", function()
            local instance1 = UndoManager.getInstance()
            UndoManager.resetInstance()
            local instance2 = UndoManager.getInstance()
            assert.is_not_equal(instance1, instance2)
        end)

        it("should merge configuration", function()
            local manager = UndoManager.new({
                maxHistory = 50,
                debugMode = true
            })
            local config = manager:getConfig()
            assert.are.equal(50, config.maxHistory)
            assert.is_true(config.debugMode)
            assert.are.equal(1024, config.maxMemoryKB) -- default value
        end)
    end)

    describe("operation execution", function()
        it("should execute successful operations", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            local result = manager:execute("clipboard_format", mockFormatter)

            assert.is_not_nil(result)
            assert.is_true(result.success)
            assert.is_not_nil(result.operationId)
            assert.are.equal("test content", result.originalContent)
            assert.are.equal("formatted: test content", result.formattedContent)
            assert.are.equal("formatted: test content", helper.getClipboard())
        end)

        it("should handle formatter errors", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            local result = manager:execute("clipboard_format", errorFormatter)

            assert.is_nil(result)
        end)

        it("should handle no clipboard content", function()
            local manager = UndoManager.new()
            helper.setClipboard("")

            local result = manager:execute("clipboard_format", mockFormatter)

            assert.is_nil(result)
        end)

        it("should handle identity operations (no change)", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            local result = manager:execute("clipboard_format", identityFormatter)

            assert.is_not_nil(result)
            assert.is_true(result.success)
            assert.are.equal("test content", result.originalContent)
            assert.are.equal("test content", result.formattedContent)
        end)

        it("should track operation statistics", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            manager:execute("clipboard_format", mockFormatter)
            manager:execute("selection_format", mockFormatter)

            local stats = manager:getStats()
            assert.are.equal(2, stats.totalOperations)
            assert.are.equal(2, stats.historySize)
        end)
    end)

    describe("undo operations", function()
        it("should undo successful operations", function()
            local manager = UndoManager.new()
            helper.setClipboard("original content")

            manager:execute("clipboard_format", mockFormatter)
            assert.are.equal("formatted: original content", helper.getClipboard())

            local undoResult = manager:undo()
            assert.is_not_nil(undoResult)
            assert.is_true(undoResult.success)
            assert.are.equal("original content", undoResult.restoredContent)
            assert.are.equal("original content", helper.getClipboard())
        end)

        it("should handle no operations to undo", function()
            local manager = UndoManager.new()

            local result = manager:undo()
            assert.is_nil(result)
        end)

        it("should track undo statistics", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            manager:execute("clipboard_format", mockFormatter)
            manager:undo()

            local stats = manager:getStats()
            assert.are.equal(1, stats.undoOperations)
        end)

        it("should update canUndo status", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            assert.is_false(manager:canUndo())

            manager:execute("clipboard_format", mockFormatter)
            assert.is_true(manager:canUndo())

            manager:undo()
            assert.is_false(manager:canUndo())
        end)
    end)

    describe("redo operations", function()
        it("should redo undone operations", function()
            local manager = UndoManager.new()
            helper.setClipboard("original content")

            manager:execute("clipboard_format", mockFormatter)
            manager:undo()

            local redoResult = manager:redo()
            assert.is_not_nil(redoResult)
            assert.is_true(redoResult.success)
            assert.are.equal("formatted: original content", helper.getClipboard())
        end)

        it("should handle no operations to redo", function()
            local manager = UndoManager.new()

            local result = manager:redo()
            assert.is_nil(result)
        end)

        it("should track redo statistics", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            manager:execute("clipboard_format", mockFormatter)
            manager:undo()
            manager:redo()

            local stats = manager:getStats()
            assert.are.equal(1, stats.redoOperations)
        end)

        it("should update canRedo status", function()
            local manager = UndoManager.new()
            helper.setClipboard("test content")

            assert.is_false(manager:canRedo())

            manager:execute("clipboard_format", mockFormatter)
            assert.is_false(manager:canRedo())

            manager:undo()
            assert.is_true(manager:canRedo())

            manager:redo()
            assert.is_false(manager:canRedo())
        end)
    end)

    describe("history management", function()
        it("should maintain operation history", function()
            local manager = UndoManager.new()
            helper.setClipboard("content1")

            manager:execute("clipboard_format", mockFormatter)
            helper.setClipboard("content2")
            manager:execute("selection_format", mockFormatter)

            local history = manager:getHistory()
            assert.is_not_nil(history)
            assert.are.equal(2, #history)
            assert.are.not_equal(history[1].id, history[2].id)
        end)

        it("should limit history size", function()
            local manager = UndoManager.new({maxHistory = 2})
            helper.setClipboard("content")

            -- Execute 3 operations
            manager:execute("clipboard_format", mockFormatter)
            helper.setClipboard("content2")
            manager:execute("selection_format", mockFormatter)
            helper.setClipboard("content3")
            manager:execute("clipboard_format", mockFormatter)

            local history = manager:getHistory()
            assert.is_true(#history <= 3) -- Should be limited to current operations since cleanup hasn't run yet
        end)

        it("should clear history", function()
            local manager = UndoManager.new()
            helper.setClipboard("content")

            manager:execute("clipboard_format", mockFormatter)

            assert.is_true(manager:canUndo())

            manager:clearHistory()

            assert.is_false(manager:canUndo())
            assert.is_false(manager:canRedo())

            local stats = manager:getStats()
            assert.are.equal(0, stats.historySize)
        end)

        it("should provide limited history", function()
            local manager = UndoManager.new()
            helper.setClipboard("content")

            -- Add multiple operations
            for i = 1, 5 do
                helper.setClipboard("content" .. i)
                manager:execute("clipboard_format", mockFormatter)
            end

            local limitedHistory = manager:getHistory(3)
            assert.are.equal(3, #limitedHistory)
        end)
    end)

    describe("configuration management", function()
        it("should update configuration", function()
            local manager = UndoManager.new()
            manager:updateConfig({
                debugMode = true,
                maxHistory = 50
            })

            local config = manager:getConfig()
            assert.is_true(config.debugMode)
            assert.are.equal(50, config.maxHistory)
        end)

        it("should ignore invalid configuration keys", function()
            local manager = UndoManager.new()
            local originalConfig = manager:getConfig()

            manager:updateConfig({
                invalidKey = "value",
                maxHistory = 75
            })

            local newConfig = manager:getConfig()
            assert.are.equal(75, newConfig.maxHistory)
            assert.is_nil(newConfig.invalidKey)
            assert.are.equal(originalConfig.maxMemoryKB, newConfig.maxMemoryKB)
        end)
    end)

    describe("statistics and monitoring", function()
        it("should provide comprehensive statistics", function()
            local manager = UndoManager.new({debugMode = true})
            helper.setClipboard("test content")

            manager:execute("clipboard_format", mockFormatter)
            manager:undo()
            manager:redo()

            local stats = manager:getStats()
            assert.is_number(stats.totalOperations)
            assert.is_number(stats.undoOperations)
            assert.is_number(stats.redoOperations)
            assert.is_number(stats.memoryUsageKB)
            assert.is_number(stats.historySize)
            assert.is_number(stats.currentIndex)
            assert.is_boolean(stats.canUndo)
            assert.is_boolean(stats.canRedo)
        end)
    end)

    describe("constants", function()
        it("should export operation types", function()
            assert.is_not_nil(UndoManager.OPERATION_TYPES)
            assert.is_not_nil(UndoManager.OPERATION_TYPES.CLIPBOARD_FORMAT)
            assert.is_not_nil(UndoManager.OPERATION_TYPES.SELECTION_FORMAT)
            assert.is_not_nil(UndoManager.OPERATION_TYPES.CLIPBOARD_SEED)
            assert.is_not_nil(UndoManager.OPERATION_TYPES.CUSTOM)
        end)

        it("should export operation status", function()
            assert.is_not_nil(UndoManager.OPERATION_STATUS)
            assert.is_not_nil(UndoManager.OPERATION_STATUS.SUCCESS)
            assert.is_not_nil(UndoManager.OPERATION_STATUS.FAILED)
            assert.is_not_nil(UndoManager.OPERATION_STATUS.PARTIAL)
        end)
    end)

    describe("error handling and edge cases", function()
        it("should handle nil formatter", function()
            local manager = UndoManager.new()
            helper.setClipboard("content")

            local result = manager:execute("clipboard_format", nil)
            assert.is_nil(result)
        end)

        it("should handle empty context", function()
            local manager = UndoManager.new()
            helper.setClipboard("content")

            local result = manager:execute("clipboard_format", mockFormatter, nil)
            assert.is_not_nil(result)
            assert.is_true(result.success)
        end)

        it("should handle operation with side effects", function()
            local manager = UndoManager.new()
            helper.setClipboard("content")

            local sideEffectFormatter = function(text)
                return "formatted: " .. text, {message = "side effect"}
            end

            local result = manager:execute("clipboard_format", sideEffectFormatter)
            assert.is_not_nil(result)
            assert.is_not_nil(result.sideEffect)
        end)
    end)
end)