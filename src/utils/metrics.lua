--[[
WHAT THIS FILE DOES:
This module provides comprehensive performance monitoring and metrics collection
for the clipboard formatting system. It tracks operation timing, success rates,
resource usage, and other key performance indicators to enable data-driven
optimization and early detection of performance regressions.

KEY CONCEPTS:
- Operation Timing: Tracks execution time for all major operations
- Success Rate Monitoring: Measures reliability and failure patterns
- Resource Usage: Monitors memory consumption and cache efficiency
- Performance Analytics: Provides aggregations and trend analysis
- Alerting: Triggers notifications for performance thresholds
- Export Capabilities: Enables integration with monitoring systems

EXAMPLE USAGE:
    local Metrics = require("src.utils.metrics")
    Metrics.startTimer("operation_name")
    -- ... perform operation ...
    Metrics.recordTimer("operation_name", true)
    local stats = Metrics.getStats()
]]

local pkgRoot = (...):match("^(.*)%.utils%.metrics$")
local hsUtils = require(pkgRoot .. ".utils.hammerspoon")

local Metrics = {}

-- Configuration
local CONFIG = {
    MAX_HISTORY_SIZE = 10000,
    ALERT_THRESHOLDS = {
        operationTimeMs = 1000,  -- Alert if operation takes > 1s
        successRate = 0.9,       -- Alert if success rate < 90%
        memoryUsageMB = 100,     -- Alert if memory > 100MB
        errorRate = 0.1,         -- Alert if error rate > 10%
    },
    SAMPLING_RATE = 1.0,         -- 100% sampling for comprehensive data
    RETENTION_HOURS = 24,         -- Keep data for 24 hours
    AUTO_CLEANUP_INTERVAL = 3600  -- Cleanup every hour
}

-- Timer management
local activeTimers = {}
local timerIdCounter = 0

-- Metrics storage
local operationMetrics = {}
local performanceHistory = {}
local alertHistory = {}
local systemStats = {
    startTime = os.time(),
    totalOperations = 0,
    totalErrors = 0,
    lastCleanupTime = os.time()
}

-- Performance aggregation cache
local aggregationCache = {}
local lastAggregationTime = 0
local AGGREGATION_INTERVAL = 60 -- seconds

-- Generate unique timer ID
local function generateTimerId()
    timerIdCounter = timerIdCounter + 1
    return ("timer_%d_%d"):format(os.time(), timerIdCounter)
end

-- Alert system
local AlertManager = {}

function AlertManager.checkThresholds(metrics, config)
    local alerts = {}
    local now = os.time()

    -- Check operation time thresholds
    if metrics.avgOperationTimeMs and metrics.avgOperationTimeMs > config.ALERT_THRESHOLDS.operationTimeMs then
        table.insert(alerts, {
            type = "performance",
            message = ("High operation time detected: %.2f ms"):format(metrics.avgOperationTimeMs),
            severity = "warning",
            timestamp = now,
            value = metrics.avgOperationTimeMs,
            threshold = config.ALERT_THRESHOLDS.operationTimeMs
        })
    end

    -- Check success rate thresholds
    if metrics.successRate and metrics.successRate < config.ALERT_THRESHOLDS.successRate then
        table.insert(alerts, {
            type = "reliability",
            message = ("Low success rate detected: %.2f%%"):format(metrics.successRate * 100),
            severity = "error",
            timestamp = now,
            value = metrics.successRate,
            threshold = config.ALERT_THRESHOLDS.successRate
        })
    end

    -- Check error rate thresholds
    if metrics.errorRate and metrics.errorRate > config.ALERT_THRESHOLDS.errorRate then
        table.insert(alerts, {
            type = "reliability",
            message = ("High error rate detected: %.2f%%"):format(metrics.errorRate * 100),
            severity = "error",
            timestamp = now,
            value = metrics.errorRate,
            threshold = config.ALERT_THRESHOLDS.errorRate
        })
    end

    -- Check memory usage thresholds
    if metrics.memoryUsageMB and metrics.memoryUsageMB > config.ALERT_THRESHOLDS.memoryUsageMB then
        table.insert(alerts, {
            type = "resource",
            message = ("High memory usage detected: %.2f MB"):format(metrics.memoryUsageMB),
            severity = "warning",
            timestamp = now,
            value = metrics.memoryUsageMB,
            threshold = config.ALERT_THRESHOLDS.memoryUsageMB
        })
    end

    return alerts
end

function AlertManager.recordAlert(alert)
    table.insert(alertHistory, {
        id = generateTimerId(),
        alert = alert,
        acknowledged = false,
        timestamp = os.time()
    })

    -- Keep alert history manageable
    while #alertHistory > 1000 do
        table.remove(alertHistory, 1)
    end
end

-- Performance aggregation
local function aggregateMetrics()
    local now = os.time()

    -- Skip aggregation if interval hasn't passed
    if now - lastAggregationTime < AGGREGATION_INTERVAL then
        return aggregationCache
    end

    local aggregations = {
        lastUpdated = now,
        operationsByType = {},
        hourlyStats = {},
        recentErrors = {},
        performanceTrends = {}
    }

    -- Aggregate by operation type
    for opType, metrics in pairs(operationMetrics) do
        if #metrics.samples > 0 then
            local totalTime = 0
            local successes = 0
            local errors = 0

            for _, sample in ipairs(metrics.samples) do
                totalTime = totalTime + sample.durationMs
                if sample.success then
                    successes = successes + 1
                else
                    errors = errors + 1
                end
            end

            aggregations.operationsByType[opType] = {
                count = #metrics.samples,
                avgTimeMs = totalTime / #metrics.samples,
                successRate = successes / #metrics.samples,
                errorRate = errors / #metrics.samples,
                minTimeMs = metrics.samples[1] and metrics.samples[1].durationMs or math.huge,
                maxTimeMs = metrics.samples[1] and metrics.samples[1].durationMs or 0
            }
        end
    end

    -- Store aggregation
    aggregationCache = aggregations
    lastAggregationTime = now

    return aggregations
end

-- Data cleanup
local function cleanupOldData()
    local now = os.time()
    local cutoffTime = now - (CONFIG.RETENTION_HOURS * 3600)

    -- Clean old performance history
    for i = #performanceHistory, 1, -1 do
        if performanceHistory[i].timestamp < cutoffTime then
            table.remove(performanceHistory, i)
        end
    end

    -- Limit operation samples per type
    for opType, metrics in pairs(operationMetrics) do
        while #metrics.samples > CONFIG.MAX_HISTORY_SIZE do
            table.remove(metrics.samples, 1)
        end
    end

    systemStats.lastCleanupTime = now
end

-- Public API
function Metrics.startTimer(operationType, metadata)
    if math.random() > CONFIG.SAMPLING_RATE then
        return nil -- Skip sampling
    end

    local timerId = generateTimerId()
    local startTime = hsUtils.now and hsUtils.now() or (os.clock() * 1000)

    activeTimers[timerId] = {
        operationType = operationType,
        startTime = startTime,
        metadata = metadata or {}
    }

    return timerId
end

function Metrics.recordTimer(timerId, success, errorMessage)
    if not activeTimers[timerId] then
        return
    end

    local timer = activeTimers[timerId]
    local endTime = hsUtils.now and hsUtils.now() or (os.clock() * 1000)
    local durationMs = endTime - timer.startTime

    -- Initialize metrics for this operation type if needed
    if not operationMetrics[timer.operationType] then
        operationMetrics[timer.operationType] = {
            samples = {},
            totalTimeMs = 0,
            successCount = 0,
            errorCount = 0
        }
    end

    -- Record the sample
    local sample = {
        timestamp = os.time(),
        durationMs = durationMs,
        success = success,
        errorMessage = errorMessage,
        metadata = timer.metadata
    }

    table.insert(operationMetrics[timer.operationType].samples, sample)
    operationMetrics[timer.operationType].totalTimeMs = operationMetrics[timer.operationType].totalTimeMs + durationMs

    if success then
        operationMetrics[timer.operationType].successCount = operationMetrics[timer.operationType].successCount + 1
    else
        operationMetrics[timer.operationType].errorCount = operationMetrics[timer.operationType].errorCount + 1
        systemStats.totalErrors = systemStats.totalErrors + 1

        -- Record error in performance history
        table.insert(performanceHistory, {
            timestamp = os.time(),
            operationType = timer.operationType,
            durationMs = durationMs,
            success = false,
            errorMessage = errorMessage,
            metadata = timer.metadata
        })
    end

    -- Record in performance history (sample only)
    if #performanceHistory < CONFIG.MAX_HISTORY_SIZE then
        table.insert(performanceHistory, {
            timestamp = os.time(),
            operationType = timer.operationType,
            durationMs = durationMs,
            success = success,
            errorMessage = errorMessage,
            metadata = timer.metadata
        })
    end

    systemStats.totalOperations = systemStats.totalOperations + 1

    -- Clean up timer
    activeTimers[timerId] = nil

    -- Check for alerts
    local currentStats = Metrics.getStats()
    local alerts = AlertManager.checkThresholds(currentStats, CONFIG)
    for _, alert in ipairs(alerts) do
        AlertManager.recordAlert(alert)
    end

    -- Periodic cleanup
    local now = os.time()
    if now - systemStats.lastCleanupTime > CONFIG.AUTO_CLEANUP_INTERVAL then
        cleanupOldData()
    end

    -- Periodic aggregation
    if now - lastAggregationTime > AGGREGATION_INTERVAL then
        aggregateMetrics()
    end
end

function Metrics.recordOperation(operationType, durationMs, success, metadata, errorMessage)
    -- Convenience method for manual recording
    local timerId = Metrics.startTimer(operationType, metadata)
    if timerId then
        -- Simulate timer completion
        local timer = activeTimers[timerId]
        timer.startTime = timer.startTime - durationMs
        Metrics.recordTimer(timerId, success, errorMessage)
    end
end

function Metrics.getStats()
    local now = os.time()
    local uptimeSeconds = now - systemStats.startTime

    -- Calculate overall stats
    local totalSuccesses = 0
    local totalSamples = 0
    local totalDuration = 0
    local recentOperations = 0
    local recentErrors = 0
    local recentHour = now - 3600

    for opType, metrics in pairs(operationMetrics) do
        totalSuccesses = totalSuccesses + metrics.successCount
        totalSamples = totalSamples + #metrics.samples
        totalDuration = totalDuration + metrics.totalTimeMs

        -- Count recent operations (last hour)
        for _, sample in ipairs(metrics.samples) do
            if sample.timestamp > recentHour then
                recentOperations = recentOperations + 1
                if not sample.success then
                    recentErrors = recentErrors + 1
                end
            end
        end
    end

    local overallSuccessRate = totalSamples > 0 and (totalSuccesses / totalSamples) or 0
    local overallErrorRate = recentOperations > 0 and (recentErrors / recentOperations) or 0
    local avgOperationTime = totalSamples > 0 and (totalDuration / totalSamples) or 0

    -- Get current memory usage
    local memoryUsageKB = collectgarbage("count")

    return {
        uptime = {
            startTime = systemStats.startTime,
            uptimeSeconds = uptimeSeconds,
            uptimeHours = uptimeSeconds / 3600
        },
        operations = {
            total = systemStats.totalOperations,
            recent = recentOperations,
            byType = {}
        },
        performance = {
            avgOperationTimeMs = avgOperationTime,
            overallSuccessRate = overallSuccessRate,
            recentErrorRate = overallErrorRate,
            samplesTracked = totalSamples
        },
        resources = {
            memoryUsageKB = memoryUsageKB,
            memoryUsageMB = memoryUsageKB / 1024,
            activeTimers = #activeTimers,
            cacheSize = #performanceHistory
        },
        alerts = {
            total = #alertHistory,
            recent = #alertHistory - math.min(10, #alertHistory) + 1,
            unacknowledged = 0 -- Would need to implement acknowledgment tracking
        }
    }
end

function Metrics.getOperationStats(operationType)
    local metrics = operationMetrics[operationType]
    if not metrics or #metrics.samples == 0 then
        return nil
    end

    local totalTime = metrics.totalTimeMs
    local count = #metrics.samples
    local successCount = metrics.successCount
    local errorCount = metrics.errorCount

    return {
        operationType = operationType,
        sampleCount = count,
        avgTimeMs = totalTime / count,
        successRate = successCount / count,
        errorRate = errorCount / count,
        successCount = successCount,
        errorCount = errorCount,
        recentSample = metrics.samples[#metrics.samples]
    }
end

function Metrics.getRecentErrors(limit)
    limit = limit or 50

    local errors = {}
    for _, entry in ipairs(performanceHistory) do
        if not entry.success then
            table.insert(errors, entry)
        end
    end

    -- Sort by timestamp descending
    table.sort(errors, function(a, b) return a.timestamp > b.timestamp end)

    -- Return limited results
    local results = {}
    for i = 1, math.min(limit, #errors) do
        table.insert(results, errors[i])
    end

    return results
end

function Metrics.getAlerts(since)
    since = since or (os.time() - 3600) -- Last hour by default

    local recentAlerts = {}
    for _, alertEntry in ipairs(alertHistory) do
        if alertEntry.alert.timestamp > since then
            table.insert(recentAlerts, alertEntry.alert)
        end
    end

    return recentAlerts
end

function Metrics.getPerformanceTrends(operationType, hours)
    hours = hours or 1
    local cutoff = os.time() - (hours * 3600)
    local samples = {}

    local metrics = operationMetrics[operationType]
    if metrics then
        for _, sample in ipairs(metrics.samples) do
            if sample.timestamp > cutoff then
                table.insert(samples, sample)
            end
        end
    end

    return samples
end

function Metrics.exportData(format)
    format = format or "json"

    local data = {
        stats = Metrics.getStats(),
        operationMetrics = {},
        alerts = alertHistory,
        performanceHistory = performanceHistory,
        exportTimestamp = os.time()
    }

    -- Convert operation metrics to exportable format
    for opType, metrics in pairs(operationMetrics) do
        data.operationMetrics[opType] = {
            samples = metrics.samples,
            successCount = metrics.successCount,
            errorCount = metrics.errorCount,
            totalTimeMs = metrics.totalTimeMs
        }
    end

    if format == "json" then
        return data -- Return as Lua table (can be converted to JSON)
    else
        return data
    end
end

function Metrics.reset()
    activeTimers = {}
    operationMetrics = {}
    performanceHistory = {}
    alertHistory = {}
    aggregationCache = {}
    lastAggregationTime = 0
    timerIdCounter = 0

    systemStats = {
        startTime = os.time(),
        totalOperations = 0,
        totalErrors = 0,
        lastCleanupTime = os.time()
    }
end

function Metrics.configure(newConfig)
    for key, value in pairs(newConfig) do
        if CONFIG[key] ~= nil then
            CONFIG[key] = value
        end
    end
end

function Metrics.getConfiguration()
    return {
        maxHistorySize = CONFIG.MAX_HISTORY_SIZE,
        alertThresholds = CONFIG.ALERT_THRESHOLDS,
        samplingRate = CONFIG.SAMPLING_RATE,
        retentionHours = CONFIG.RETENTION_HOURS,
        autoCleanupInterval = CONFIG.AUTO_CLEANUP_INTERVAL
    }
end

return Metrics