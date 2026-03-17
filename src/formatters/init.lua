-- Formatters module - exports all formatter modules
local pkgRoot = (...):match("^(.*)%.formatters$")

local M = {
    arithmetic = require(pkgRoot and (pkgRoot .. ".formatters.arithmetic") or "formatters.arithmetic"),
    currency = require(pkgRoot and (pkgRoot .. ".formatters.currency") or "formatters.currency"),
    date = require(pkgRoot and (pkgRoot .. ".formatters.date") or "formatters.date"),
    phone = require(pkgRoot and (pkgRoot .. ".formatters.phone") or "formatters.phone"),
}

return M
