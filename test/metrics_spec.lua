---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
local Metrics = helper.requireFresh("utils.metrics")

describe("Metrics", function()
    before_each(function()
        Metrics.reset()
    end)

    describe("timer operations", function()
        it("should start and record timers", function()
            local timerId = Metrics.startTimer("test_operation")
            assert.is_not_nil(timerId)
            assert.is_string(timerId)

            Metrics.recordTimer(timerId, true)

            local stats = Metrics.getStats()
            assert.are.equal(1, stats.operations.total)
            assert.are.equal(0, stats.operations.recent) -- Recent is hour-based
        end)

        it("should handle failed operations", function()
            local timerId = Metrics.startTimer("test_operation")
            Metrics.recordTimer(timerId, false, "Test error")

            local stats = Metrics.getStats()
            assert.are.equal(1, stats.operations.total)
            -- Performance stats should include errors
        end)

        it("should handle timer recording without valid timer", function()
            -- Should not crash
            Metrics.recordTimer("invalid_timer_id", true)

            local stats = Metrics.getStats()
            assert.are.equal(0, stats.operations.total)
        end)

        it("should record manual operations", function()
            Metrics.recordOperation("manual_op", 150, true, {key = "value"})

            local stats = Metrics.getStats()
            assert.are.equal(1, stats.operations.total)
            assert.is_number(stats.performance.avgOperationTimeMs)
        end)
    end)

    describe("statistics calculation", function()
        it("should calculate correct statistics", function()
            -- Record some operations
            Metrics.recordOperation("fast_op", 10, true)
            Metrics.recordOperation("slow_op", 200, true)
            Metrics.recordOperation("failed_op", 50, false)

            local stats = Metrics.getStats()
            assert.are.equal(3, stats.operations.total)
            assert.is_number(stats.performance.avgOperationTimeMs)
            assert.is_number(stats.performance.overallSuccessRate)
            assert.is_number(stats.performance.recentErrorRate)
            assert.is_true(stats.performance.overallSuccessRate > 0)
        end)

        it("should handle zero operations", function()
            local stats = Metrics.getStats()
            assert.are.equal(0, stats.operations.total)
            assert.are.equal(0, stats.performance.avgOperationTimeMs)
            assert.are.equal(0, stats.performance.overallSuccessRate)
        end)

        it("should track uptime", function()
            local stats = Metrics.getStats()
            assert.is_not_nil(stats.uptime.startTime)
            assert.is_number(stats.uptime.uptimeSeconds)
            assert.is_true(stats.uptime.uptimeSeconds >= 0)
        end)
    end)

    describe("operation-specific metrics", function()
        it("should track metrics by operation type", function()
            Metrics.recordOperation("type_a", 100, true)
            Metrics.recordOperation("type_a", 200, true)
            Metrics.recordOperation("type_b", 150, false)

            local statsA = Metrics.getOperationStats("type_a")
            local statsB = Metrics.getOperationStats("type_b")

            assert.is_not_nil(statsA)
            assert.are.equal(2, statsA.sampleCount)
            assert.are.equal(150, statsA.avgTimeMs) -- (100 + 200) / 2
            assert.are.equal(1.0, statsA.successRate)
            assert.are.equal(2, statsA.successCount)
            assert.are.equal(0, statsA.errorCount)

            assert.is_not_nil(statsB)
            assert.are.equal(1, statsB.sampleCount)
            assert.are.equal(150, statsB.avgTimeMs)
            assert.are.equal(0, statsB.successRate)
            assert.are.equal(0, statsB.successCount)
            assert.are.equal(1, statsB.errorCount)
        end)

        it("should return nil for unknown operation types", function()
            local stats = Metrics.getOperationStats("unknown_operation")
            assert.is_nil(stats)
        end)
    end)

    describe("error tracking", function()
        it("should record and retrieve recent errors", function()
            Metrics.recordOperation("error_op", 100, false, "Error message 1")
            Metrics.recordOperation("error_op", 150, false, "Error message 2")
            Metrics.recordOperation("success_op", 50, true)

            local recentErrors = Metrics.getRecentErrors(10)
            assert.are.equal(2, #recentErrors)
            assert.is_false(recentErrors[1].success)
            assert.is_false(recentErrors[2].success)
            assert.is_string(recentErrors[1].errorMessage)
        end)

        it("should limit error results", function()
            -- Record more errors than the limit
            for i = 1, 20 do
                Metrics.recordOperation("error_op", 100, false, ("Error %d"):format(i))
            end

            local recentErrors = Metrics.getRecentErrors(5)
            assert.are.equal(5, #recentErrors)
        end)
    end)

    describe("alert system", function()
        it("should track alert thresholds", function()
            -- Create some operations to trigger potential alerts
            for i = 1, 10 do
                local success = i <= 8 -- 2 failures out of 10 = 80% success rate
                local duration = i == 5 and 1500 or 100 -- One slow operation
                Metrics.recordOperation("alert_test", duration, success)
            end

            local stats = Metrics.getStats()
            -- Stats should be calculated even if alerts aren't explicitly tested
            assert.is_number(stats.performance.overallSuccessRate)
            assert.is_number(stats.performance.avgOperationTimeMs)
        end)

        it("should retrieve recent alerts", function()
            local alerts = Metrics.getAlerts()
            assert.is_table(alerts)
            -- Alert count depends on threshold configuration
        end)
    end)

    describe("resource monitoring", function()
        it("should track memory usage", function()
            local stats = Metrics.getStats()
            assert.is_number(stats.resources.memoryUsageKB)
            assert.is_number(stats.resources.memoryUsageMB)
            assert.is_true(stats.resources.memoryUsageKB > 0)
        end)

        it("should track active timers", function()
            local timerId1 = Metrics.startTimer("active_test")
            local timerId2 = Metrics.startTimer("active_test")

            local stats = Metrics.getStats()
            assert.are.equal(2, stats.resources.activeTimers)

            Metrics.recordTimer(timerId1, true)
            stats = Metrics.getStats()
            assert.are.equal(1, stats.resources.activeTimers)

            Metrics.recordTimer(timerId2, true)
            stats = Metrics.getStats()
            assert.are.equal(0, stats.resources.activeTimers)
        end)
    end)

    describe("performance trends", function()
        it("should retrieve performance trends", function()
            -- Record some operations over time
            for i = 1, 5 do
                Metrics.recordOperation("trend_test", 100 + (i * 10), i % 3 ~= 0)
                os.execute("sleep 0.001") -- Small delay to vary timestamps
            end

            local trends = Metrics.getPerformanceTrends("trend_test", 1)
            assert.is_table(trends)
            assert.is_true(#trends >= 5)
            assert.is_number(trends[1].durationMs)
            assert.is_boolean(trends[1].success)
        end)
    end)

    describe("data export", function()
        it("should export comprehensive data", function()
            Metrics.recordOperation("export_test", 120, true, {export = true})

            local exportData = Metrics.exportData()
            assert.is_not_nil(exportData.stats)
            assert.is_not_nil(exportData.operationMetrics)
            assert.is_not_nil(exportData.alerts)
            assert.is_not_nil(exportData.performanceHistory)
            assert.is_number(exportData.exportTimestamp)

            -- Check that export contains our test operation
            assert.is_not_nil(exportData.operationMetrics.export_test)
        end)
    end)

    describe("configuration", function()
        it("should update configuration", function()
            local originalConfig = Metrics.getConfiguration()

            Metrics.configure({
                samplingRate = 0.5
            })

            local newConfig = Metrics.getConfiguration()
            assert.are.equal(0.5, newConfig.samplingRate)
            -- Other values should remain unchanged
            assert.are.equal(originalConfig.maxHistorySize, newConfig.maxHistorySize)
        end)

        it("should ignore invalid configuration keys", function()
            local originalConfig = Metrics.getConfiguration()

            Metrics.configure({
                invalidKey = "value",
                samplingRate = 0.75
            })

            local newConfig = Metrics.getConfiguration()
            assert.are.equal(0.75, newConfig.samplingRate)
            assert.is_nil(newConfig.invalidKey)
        end)
    end)

    describe("cleanup and maintenance", function()
        it("should reset all metrics", function()
            Metrics.recordOperation("reset_test", 100, true)
            Metrics.startTimer("reset_timer")

            local statsBefore = Metrics.getStats()
            assert.are.equal(1, statsBefore.operations.total)
            assert.are.equal(1, statsBefore.resources.activeTimers)

            Metrics.reset()

            local statsAfter = Metrics.getStats()
            assert.are.equal(0, statsAfter.operations.total)
            assert.are.equal(0, statsAfter.resources.activeTimers)
        end)

        it("should handle sampling rate", function()
            Metrics.configure({samplingRate = 0.0}) -- 0% sampling

            local timerId = Metrics.startTimer("sampled_test")
            assert.is_nil(timerId) -- Should not start timer due to 0% sampling

            Metrics.configure({samplingRate = 1.0}) -- 100% sampling
            timerId = Metrics.startTimer("sampled_test")
            assert.is_not_nil(timerId) -- Should start timer now
        end)
    end)
end)