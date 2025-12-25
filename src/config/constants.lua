--[[
Centralized constants for ClipboardFormatter

All magic numbers and configuration values are defined here
for easy maintenance and consistency.
]]

local M = {}

-- Detector Priorities
-- Higher priority detectors are evaluated first
M.PRIORITY = {
    ARITHMETIC = 100,
    PD_CONVERSION = 70,
    COMBINATIONS = 60,
    NAVIGATION = 10000,  -- Deliberately low priority
    PHONE = 90
}

-- Time Constants (milliseconds)
M.TIME = {
    SELECTION_COPY_DELAY = 300,
    SELECTION_TIMEOUT = 600,
    SELECTION_PASTE_DELAY = 60,
    SELECTION_FALLBACK_DELAY = 20000,
    THROTTLE_DEFAULT = 500
}

-- Cache Constants
M.CACHE = {
    PATTERN_MAX_SIZE = 100,
    PATTERN_MEMORY_THRESHOLD_MB = 10,
    LRU_INITIAL_CAPACITY = 50
}

-- Pattern Names
M.PATTERNS = {
    ARITHMETIC = "arithmetic",
    COMBINATION = "combination",
    PHONE = "phone"
}

-- Error Messages
M.ERRORS = {
    MISSING_DEPENDENCY = "missing required dependency",
    INVALID_DETECTOR_SPEC = "invalid detector specification",
    PATTERN_NOT_FOUND = "pattern not found in registry",
    FORMATTER_MISSING = "formatter method not found"
}

-- PD (Permanent Disability) Defaults
M.PD = {
    BENEFIT_PER_WEEK = 290
}

-- File Paths (can be overridden by environment)
-- Handle test environment where hs is not available
local hs = _G.hs
M.PATHS = {
    -- PD mapping files
    PD_BUNDLED = "data/pd_percent_to_weeks.txt",
    PD_LEGACY = "PD - percent to weeks.txt",
    PD_FALLBACK = hs and hs.configdir and (hs.configdir .. "/PD - percent to weeks.txt") or "/Users/jason/Scripts/Python/JJK_PdtoWeeksDollars/PD - percent to weeks.txt"
}

-- Validation Constants
M.VALIDATION = {
    MAX_CLIPBOARD_LENGTH = 100000,
    MAX_SELECTION_RETRIES = 3
}

return M
