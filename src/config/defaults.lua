local pkgRoot = (...):match("^(.*)%.config%.defaults$")
local constants = require(pkgRoot and (pkgRoot .. ".config.constants") or "ClipboardFormatter.src.config.constants")

return {
    loggerLevel = "warning",
    logging = {
        level = nil,
        structured = false,
        includeTimestamp = true,
    },
    restoreClipboard = true,
    finderReplacement = {
        default = "bloom",
    },
    processing = {
        throttleMs = constants.TIME.THROTTLE_DEFAULT,
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
        copyDelayMs = constants.TIME.SELECTION_COPY_DELAY,
        pasteDelayMs = constants.TIME.SELECTION_PASTE_DELAY,
        pollIntervalMs = 50,
        maxPolls = 8,
        retryWithEventtap = true,
    },
    pd = {
        bundledFile = constants.PATHS.PD_BUNDLED,
        legacyFile = constants.PATHS.PD_LEGACY,
        fallbackPath = constants.PATHS.PD_FALLBACK,
        benefitPerWeek = constants.PD.BENEFIT_PER_WEEK,
    },
}
