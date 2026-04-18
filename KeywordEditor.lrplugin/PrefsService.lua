local LrPrefs = import 'LrPrefs'

local PrefsService = {}

local PREF_KEY = 'recentlyUsedKeywords'

local function sanitizeList(list)
    if type(list) ~= 'table' then return {} end

    local out = {}
    for _, item in ipairs(list) do
        if type(item) == 'table' and type(item.name) == 'string' then
            local name = item.name
            local clicks = tonumber(item.clicks) or 0
            if name ~= '' then
                out[#out + 1] = { name = name, clicks = clicks }
            end
        end
    end
    return out
end

function PrefsService.loadRecent(toolkitId)
    local prefs = LrPrefs.prefsForPlugin(toolkitId)
    return sanitizeList(prefs[PREF_KEY])
end

function PrefsService.saveRecent(toolkitId, items)
    local prefs = LrPrefs.prefsForPlugin(toolkitId)
    prefs[PREF_KEY] = sanitizeList(items)
end

return PrefsService
