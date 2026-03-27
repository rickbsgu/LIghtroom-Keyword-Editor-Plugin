local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'

local KeywordService = require 'KeywordService'
local RecentlyUsed = require 'RecentlyUsed'
local PrefsService = require 'PrefsService'
local okLogService, LogService = pcall(require, 'LogService')

local UI = {}

local function trace(context, msg)
    if not okLogService or not LogService or type(LogService.append) ~= 'function' then
        return
    end
    local logPath = '~/Library/Logs/Adobe/Lightroom/GBKeywordEditor.log'
    if _G and type(_G.GBKeywordEditorLogPath) == 'string' and _G.GBKeywordEditorLogPath ~= '' then
        logPath = _G.GBKeywordEditorLogPath
    end

    local prefix = 'UI'
    if context and type(context) == 'table' then
        local toolkitId = context.toolkitId
        if type(toolkitId) == 'string' and toolkitId ~= '' then
            prefix = prefix .. ' ' .. toolkitId
        end
    end

    LogService.append(logPath, string.format('%s: %s', prefix, tostring(msg)))
end

local function trim(s)
    if not s then return '' end
    s = tostring(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function ensureRow(props)
    if not props.rows then props.rows = {} end
end

local function addRow(props)
    ensureRow(props)
    local row = {
        count = '',
        keyword = '',
    }
    table.insert(props.rows, row)
    props.currentRow = #props.rows
end

local function deleteRow(props, index)
    if not props.rows or not props.rows[index] then return end
    table.remove(props.rows, index)
    props.currentRow = 0
end

local function setCurrentRow(props, index)
    if not props.rows or not props.rows[index] then return end
    props.currentRow = index
end

local function updateCountForRow(context)
    local props = context.props
    local rowIndex = props.currentRow
    if not rowIndex or rowIndex <= 0 then return end
    local row = props.rows[rowIndex]
    if not row then return end

    local count = KeywordService.countPhotosWithKeywordName(context.catalog, row.keyword)
    row.count = tostring(count)
    props.rows = props.rows
    trace(context, string.format('updateCountForRow: %s -> %s', tostring(row.keyword), tostring(row.count)))
end

local function refreshSuggestions(context)
    local props = context.props
    if props.suggestionsDismissed then
        props.suggestions = {}
        return
    end

    local idx = props.currentRow
    if not idx or idx <= 0 then
        props.suggestions = {}
        return
    end
    local row = props.rows[idx]
    if not row then
        props.suggestions = {}
        return
    end

    local prefix = trim(row.keyword)
    if prefix == '' then
        props.suggestions = {}
        return
    end

    props.suggestions = KeywordService.searchKeywordNames(prefix, context.allKeywordNames, 7)
end

local function applyKeywordToSelection(context, keywordName)
    keywordName = trim(keywordName)
    if keywordName == '' then return end

    local kw = KeywordService.findKeywordByName(context.catalog, keywordName)
    if not kw then
        local btn = LrDialogs.confirm(
            'Confirm New Keyword',
            'Keyword "' .. keywordName .. '" does not exist. Create it?',
            'Ok',
            'Cancel'
        )
        if btn ~= 'ok' then
            return
        end
        kw = KeywordService.ensureKeywordExists(context.catalog, keywordName)
    end

    if not kw then
        return
    end

    KeywordService.applyKeywordToPhotos(context.catalog, kw, context.targetPhotos)
    RecentlyUsed.bump(context.recent, keywordName)
    PrefsService.saveRecent(context.toolkitId, RecentlyUsed.exportItems(context.recent))
    updateCountForRow(context)
    context.props.recentVersion = (context.props.recentVersion or 0) + 1
    context.props.suggestions = {}
end

local function loadRowsFromSelection(context)
    local props = context.props
    local rows = context.initialRows
    if not rows then
        -- Fallback (no counts): just list union names.
        local photos = context.targetPhotos or {}
        local data = KeywordService.getKeywordNameUnionForPhotos(photos)
        rows = {}
        for _, name in ipairs(data.names) do
            rows[#rows + 1] = { count = '', keyword = name }
        end
    else
        -- Normalize rows coming from task precomputation.
        -- Expected UI row shape is { keyword = <string>, count = <string|number> }.
        local normalized = {}
        for _, r in ipairs(rows) do
            if type(r) == 'table' then
                local keyword = r.keyword or r.name or ''
                local count = r.count
                if count == nil then count = '' end
                normalized[#normalized + 1] = { keyword = keyword, count = tostring(count) }
            end
        end
        rows = normalized
    end

    props.rows = rows
    props.currentRow = (#rows > 0) and 1 or 0
    refreshSuggestions(context)
end

local function buildRowsView(f, context)
    local props = context.props

    local children = {}

    for i, row in ipairs(props.rows or {}) do
        children[#children + 1] = f:row {
            spacing = 2,

            f:static_text {
                width_in_chars = 1,
                title = (props.currentRow == i) and '>' or ' ',
            },

            f:static_text {
                width_in_chars = 3,
                title = row.count or '',
                alignment = 'right',
                mouse_down = function()
                    setCurrentRow(props, i)
                end,
            },

            f:edit_field {
                width_in_chars = 24,
                value = row.keyword or '',
                immediate = true,
                mouse_down = function()
                    setCurrentRow(props, i)
                    props.suggestionsDismissed = false
                    refreshSuggestions(context)
                end,
                value_change = function(v)
                    row.keyword = v
                    refreshSuggestions(context)
                end,
                action = function()
                    applyKeywordToSelection(context, row.keyword)
                end,
            },

            f:push_button {
                title = 'X',
                width = 24,
                action = function()
                    deleteRow(props, i)
                end,
            },
        }
    end

    return f:column {
        spacing = f:control_spacing(),
        unpack(children),
    }
end

local function buildSuggestionsView(f, context)
    local props = context.props

    local children = {}
    if props.suggestionsDismissed then
        children[#children + 1] = f:row {
            spacing = f:control_spacing(),
            f:static_text { title = 'Suggestions dismissed' },
            f:push_button {
                title = 'Show',
                action = function()
                    props.suggestionsDismissed = false
                    refreshSuggestions(context)
                end,
            },
        }
        return f:column { spacing = f:control_spacing(), unpack(children) }
    end

    if not props.suggestions or #props.suggestions == 0 then
        return f:column { spacing = f:control_spacing(), f:static_text { title = '' } }
    end

    children[#children + 1] = f:static_text { title = 'Suggestions:' }
    for _, name in ipairs(props.suggestions) do
        children[#children + 1] = f:push_button {
            title = name,
            action = function()
                local idx = props.currentRow
                if not idx or idx <= 0 then return end
                if not props.rows or not props.rows[idx] then return end
                props.rows[idx].keyword = name
                refreshSuggestions(context)
            end,
        }
    end

    children[#children + 1] = f:push_button {
        title = 'Dismiss',
        action = function()
            props.suggestionsDismissed = true
            props.suggestions = {}
        end,
    }

    return f:column { spacing = f:control_spacing(), unpack(children) }
end

local function buildRecentView(f, context)
    local props = context.props

    local children = {}
    for _, name in ipairs(RecentlyUsed.getNames(context.recent)) do
        children[#children + 1] = f:push_button {
            title = name,
            action = function()
                local idx = props.currentRow
                if not idx or idx <= 0 then return end
                if not props.rows or not props.rows[idx] then return end

                props.rows[idx].keyword = name
                RecentlyUsed.bump(context.recent, name)
                PrefsService.saveRecent(context.toolkitId, RecentlyUsed.exportItems(context.recent))
                props.recentVersion = (props.recentVersion or 0) + 1
                applyKeywordToSelection(context, name)
            end,
        }
    end

    return f:row { spacing = f:control_spacing(), unpack(children) }
end

function UI.showEditor(context)
    LrFunctionContext.callWithContext('GBKeywordEditor', function(fc)
        trace(context, 'showEditor: begin')
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(fc)

        context.props = props
        context.recent = RecentlyUsed.new(10)
        context.toolkitId = context.toolkitId or 'com.gb.keywordeditor.dev2'
        RecentlyUsed.loadInto(context.recent, PrefsService.loadRecent(context.toolkitId))
        context.allKeywordNames = KeywordService.getAllKeywordNames(context.catalog)
        trace(context, string.format('showEditor: loaded %d keyword names', context.allKeywordNames and #context.allKeywordNames or 0))

        props.rows = {}
        props.currentRow = 0
        props.recentVersion = 0
        props.suggestions = {}
        props.suggestionsVersion = 0
        props.suggestionsDismissed = false

        loadRowsFromSelection(context)
        trace(context, string.format('showEditor: rows=%d currentRow=%d', props.rows and #props.rows or 0, tonumber(props.currentRow) or 0))

        local function buildDebugText()
            local lines = {}
            lines[#lines + 1] = 'DEBUG:'

            lines[#lines + 1] = string.format('Selected photos: %s', tostring(context.targetPhotos and #context.targetPhotos or 0))
            lines[#lines + 1] = string.format('Initial rows: %s', tostring(context.initialRows and #context.initialRows or 0))
            lines[#lines + 1] = string.format('catalog.findPhotos type: %s (must be called in LrTask)', tostring(type(context.catalog.findPhotos)))

            return table.concat(lines, '\n')
        end

        local content = f:column {
            spacing = f:control_spacing(),
            fill_horizontal = 1,

            f:edit_field {
                value = (context.debugText and (context.debugText .. '\n\n' .. buildDebugText())) or buildDebugText(),
                width_in_chars = 70,
                height_in_lines = 10,
                tooltip = 'Debug output (temporary). You can select/copy this text.',
            },

            f:row {
                fill_horizontal = 1,
                f:spacer { fill_horizontal = 1 },
                f:push_button {
                    title = 'Create Keyword',
                    action = function()
                        addRow(props)
                        props.rows = props.rows
                        props.suggestionsDismissed = false
                        refreshSuggestions(context)
                    end,
                },
            },

            f:separator { fill_horizontal = 1 },

            f:group_box {
                title = 'Keywords',
                fill_horizontal = 1,
                buildRowsView(f, context),
            },

            f:group_box {
                title = 'Completion',
                fill_horizontal = 1,
                buildSuggestionsView(f, context),
            },

            f:separator { fill_horizontal = 1 },

            f:group_box {
                title = 'Recently Used Keywords',
                fill_horizontal = 1,
                buildRecentView(f, context),
            },
        }

        local result = LrDialogs.presentModalDialog {
            title = 'GB Keyword Editor',
            contents = content,
            actionVerb = 'Close',
        }

        trace(context, string.format('showEditor: dialog closed result=%s', tostring(result)))

        return result
    end)
end

return UI
