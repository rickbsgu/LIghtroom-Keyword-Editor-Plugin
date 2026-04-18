local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

local UI = require 'UI'
local KeywordService = require 'KeywordService'
local LogService = require 'LogService'

--[[
if not status then
  LrDialogs.message('OpenKeywordEditor, requireKeywordService error: ' .. KeywordService)
end
]]

LrTasks.startAsyncTask(function()
    LogService.open()
    LogService.append("starting the plugin")
    LogService.append("SDK Version: " .. LrApplication.versionString())
    local catalog = LrApplication.activeCatalog()
    if not catalog then
        LogService.append('No active catalog')
        LrDialogs.message('GB Keyword Editor', 'No active catalog.', 'warning')
        return
    end

    local targetPhotos = catalog:getTargetPhotos() or {}
    LogService.append(string.format('Target photos: %d', #targetPhotos))
    if #targetPhotos == 0 then
        LrDialogs.message('GB Keyword Editor', 'Select one or more photos in Grid view.', 'info')
        return
    end

    -- Precompute initial rows with counts so the modal can render quickly.
    local kwData = KeywordService.getKeywordDataForPhotos(targetPhotos)
    local catalogCountsByName = KeywordService.getCatalogKeywordCountsByName(catalog, kwData.names or {})
    local initialRows = {}
    for _, name in ipairs(kwData.names or {}) do
        local count = catalogCountsByName[name] or 0
        initialRows[#initialRows + 1] = {
            keyword = name,
            count = count,
            keywordRef = kwData.keywordByName and kwData.keywordByName[name],
        }
    end

    LogService.append(string.format('Initial rows: %d', #initialRows))

    UI.showEditor {
        catalog = catalog,
        targetPhotos = targetPhotos,
        initialRows = initialRows,
        toolkitId = (_PLUGIN and _PLUGIN.id) or 'com.gb.keywordeditor',
    }
end)
