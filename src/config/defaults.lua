return {
    loggerLevel = "warning",
    logging = {
        level = nil,
        structured = false,
        includeTimestamp = true,
    },
    restoreClipboard = true,
    processing = {
        throttleMs = 500,
    },
    templates = {
        arithmetic = nil,
    },
    hotkeys = {
        installHelpers = false,
    },
    selection = {
        waitAfterClearMs = 100,
        modifierCheckInterval = 50,
        copyDelayMs = 300,
        pasteDelayMs = 60,
        pollIntervalMs = 50,
        maxPolls = 8,
        retryWithEventtap = true,
    },
    pd = {
        bundledFile = "data/pd_percent_to_weeks.txt",
        legacyFile = "PD - percent to weeks.txt",
        fallbackPath = "/Users/jason/Scripts/Python/JJK_PDtoWeeksDollars/PD - percent to weeks.txt",
        benefitPerWeek = 290,
    },
}
