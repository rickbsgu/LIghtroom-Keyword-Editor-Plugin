local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'

local KeywordService = require 'KeywordService'
local RecentlyUsed = require 'RecentlyUsed'
local PrefsService = require 'PrefsService'
local LogService = require 'LogService'

local UI = {}
local loadRowsFromSelection

local MAX_KEYWORDS = 50
local MAX_SUGGESTIONS = 9
local ROW_VERTICAL_GAP = 6
local KEYWORD_LIST_BG = LrColor(0.94, 0.94, 0.94)
local DIALOG_WIDTH = 320
local ROW_SPACING = 2
local ROW_COUNT_WIDTH_PX = 30
local ROW_KEYWORD_WIDTH_PX = 200
local ROW_DELETE_WIDTH_PX = 30
local SHOW_LAYOUT_FRAMES = true
local FRAME_COUNT_BG = LrColor(0.97, 0.90, 0.90)
local FRAME_KEYWORD_BG = LrColor(0.90, 0.95, 0.98)
local FRAME_DELETE_BG = LrColor(0.92, 0.97, 0.90)
local UI_UPDATE_NUMBER = 14
local SUGGESTIONS_PFX = 'suggestions_pfx_'
local RECENTLY_USED_PFX = 'recently_used_pfx_'

local function trim(s)
    if not s then return '' end
    s = tostring(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function clipText(s, maxLen)
    s = tostring(s or '')
    if #s <= maxLen then return s end
    if maxLen <= 3 then return s:sub(1, maxLen) end
    return s:sub(1, maxLen - 3) .. '...'
end

local function rowVisibleKey(i) return 'row_' .. tostring(i) .. '_visible' end
local function rowCountKey(i) return 'row_' .. tostring(i) .. '_count' end
local function rowKeywordKey(i) return 'row_' .. tostring(i) .. '_keyword' end
local function suggestionTitleKey(i) return 'suggestion_' .. tostring(i) .. '_title' end

--[[
  Takes the rows obtained from 'loadRowsFromSelection' and creates
  a 'props' structure from the items. The props are what are used to
  create the view rows.
]]
local function syncRowsToProps(context)
    local props = context.props
    

    for i = 1, MAX_KEYWORDS do
        local row = context.rows[i]
        props[rowVisibleKey(i)] = row and true or false
        props[rowCountKey(i)] = row and tostring(row.count or '') or ''
        props[rowKeywordKey(i)] = row and tostring(row.keyword or '') or ''
    end

    props.rows = context.rows
    props.rowCount = #props.rows
end

local function refreshRecentlyUsed(context)
    local props = context.props
    local kwItems = RecentlyUsed.getNames(context.recent)

    for i, text in ipairs(kwItems) do
      props[RECENTLY_USED_PFX .. i] = text
    end
end

local function refreshSuggestions(context)
    local props = context.props
    local prefix = trim(props.pendingNewKeyword or '')
    local kwds = KeywordService.searchKeywordNames(prefix, context.allKeywordNames, MAX_SUGGESTIONS)
    props.hasSuggestions = #kwds > 0
    for ix = 1, #kwds do
        local name = kwds[ix]
        props[SUGGESTIONS_PFX .. ix] = name or nil
    end
end

local function applyKeywordToSelection(context, keywordName, opts)
    keywordName = trim(keywordName)
    if keywordName == '' then return end
    opts = opts or {}

    LrTasks.startAsyncTask(function()
        local kw = KeywordService.findKeywordByName(context.catalog, keywordName)
        if not kw then
            local btn = LrDialogs.confirm(
                'Confirm New Keyword',
                'Keyword "' .. keywordName .. '" does not exist. Create it?',
                'Ok',
                'Cancel'
            )
            if btn ~= 'ok' then return end
            kw = KeywordService.addNewKeyword(context.catalog, keywordName)
            if kw then
                -- Refresh so future completions include the newly created keyword.
                context.allKeywordNames = KeywordService.getAllKeywordNames(context.catalog)
            end
        end

        KeywordService.applyKeywordToPhotos(context.catalog, kw, context.targetPhotos)
        RecentlyUsed.bump(context.recent, keywordName)
        PrefsService.saveRecent(context.toolkitId, RecentlyUsed.exportItems(context.recent))
        context.props.recentVersion = (context.props.recentVersion or 0) + 1

        -- Reload rows from fresh catalog state (deduplicates, updates all counts).
        loadRowsFromSelection(context)

        local rows = context.rows or {}
        local matchedIndex = 0
        for idx, row in ipairs(rows) do
            if row.keyword == keywordName then
                matchedIndex = idx
                break
            end
        end

        refreshRecentlyUsed(context)
        refreshSuggestions(context)
        syncRowsToProps(context)
    end)
end

local function deleteRow(context, index)
    local rows = context.rows or {}
    local row = rows[index]
    if not row then return end

    -- Optimistic UI update so the row disappears immediately.
    local keywordName = trim(row.keyword)
    table.remove(rows, index)
    context.rows = rows
    context.props.suggestionsDismissed = false
    refreshSuggestions(context)
    syncRowsToProps(context)

    LrTasks.startAsyncTask(function()
        local kw = row.keywordRef

        if not kw and keywordName ~= '' then
            kw = KeywordService.findKeywordByName(context.catalog, keywordName)
        end

        if kw then
            KeywordService.removeKeywordFromPhotos(context.catalog, kw, context.targetPhotos)
            LogService.append(string.format('delete-row applied for %s', tostring(keywordName)))
        else
            LogService.append(string.format('delete-row could not resolve keyword for %s', tostring(keywordName)))
        end

        -- Reconcile rows from fresh selected-photo state after deletion.
        context.targetPhotos = context.catalog:getTargetPhotos() or context.targetPhotos
        loadRowsFromSelection(context)
        syncRowsToProps(context)
    end)
end

--[[
  Fetches keywords from the KeywordService and creates rows containing
    1. The keyword
    2. The countsByName of that keyword
    3. The LrKeyword object
]]
loadRowsFromSelection = function(context)
    local rows = {}

    local kwData = KeywordService.getKeywordDataForPhotos(context.targetPhotos or {})
    local countsByName = KeywordService.getCatalogKeywordCountsByName(context.catalog, kwData.names or {})

    for _, name in ipairs(kwData.names or {}) do
        rows[#rows + 1] = {
            keyword = name,
            count = tostring(countsByName[name] or 0),
            keywordRef = kwData.keywordByName and kwData.keywordByName[name],
        }
    end

    context.rows = rows
    refreshSuggestions(context)
    syncRowsToProps(context)
end

--[[ 
  Build the rows view
  This uses the 'props' structure built from the rows
  obtained from 'syncRowsToProps'
]]
local function buildRowsView(f, context)
    local props = context.props
    local bind = LrView.bind
    local children = {}
    for ix = 1, MAX_KEYWORDS do
        local row = props.rows[ix]
        local rowView = f:view {
            bind_to_object = props,
            visible = bind(rowVisibleKey(ix)),
            f:column {
                spacing = 0,
                f:row {
                    spacing = ROW_SPACING,
                    f:static_text {
                        width = ROW_COUNT_WIDTH_PX,
                        title = bind(rowCountKey(ix)),
                        alignment = 'right',
                    },
                    f:spacer { width = 30 },
                    f:static_text {
                        width = ROW_KEYWORD_WIDTH_PX,
                        title = bind(rowKeywordKey(ix)),
                    },
                    f:push_button {
                        visible = bind(rowVisibleKey(ix)),
                        title = 'X',
                        width = ROW_DELETE_WIDTH_PX,
                        action = function()
                            deleteRow(context, ix)
                        end,
                    },
                },
                f:spacer { height = ROW_VERTICAL_GAP },
            },
        }
        children[ix] = rowView
    end
    return f:scrolled_view {
        height = 220,
        width = DIALOG_WIDTH,
        horizontal_scroller = false,
        vertical_scroller = true,
        background_color = KEYWORD_LIST_BG,

        f:view {
            background_color = KEYWORD_LIST_BG,

            f:column {
                spacing = 0,
                unpack(children),
            },
        },
    }
end

local function createGrid(f, context, pfx, fc, actionFn)
    local bind = LrView.bind
    local columnItems = { spacing = 0 }
    local kwdIX = 1
    local props = context.props
    local CELL_WIDTH = (DIALOG_WIDTH / 3) - 3
    

    columnItems[#columnItems + 1] = f:separator { fill_horizontal = 1 }
    for i = 1, 3 do
        local rowItems = { spacing = 0 }
        
        rowItems[#rowItems + 1] = f:separator { fill_vertical = 1 }
        for j = 1, 3 do
            local cellKey = pfx .. kwdIX
            rowItems[#rowItems + 1] = f:column {
                width = CELL_WIDTH,
                height = 30,
                spacing = 0,
                f:spacer { fill_vertical = 1 },
                f:static_text {
                    title = LrView.bind({
                      bind_to_object = props,
                      key = cellKey
                    }),
                    width = CELL_WIDTH - 2,
                    alignment = 'center',
                    mouse_down = function()
                      if props[cellKey] then 
                        actionFn(props[cellKey])
                      end
                    end
                },
                f:spacer { fill_vertical = 1 },
            }

            rowItems[#rowItems + 1] = f:separator { fill_vertical = 1 }

            kwdIX = kwdIX + 1
        end -- loop
        
        -- Add the row to the main grid container
        columnItems[#columnItems + 1] = f:row (rowItems)
        columnItems[#columnItems + 1] = f:separator { fill_horizontal = 1 }
    end

    return f:column(columnItems)
end


--[[
  Build the suggestions view
]]
local function buildSuggestionsView(f, context, fc)
    local props = context.props
    local bind = LrView.bind

    return f:view {
      width = DIALOG_WIDTH,
      height = 26,
      createGrid(f, context, SUGGESTIONS_PFX, fc,
               function(kwd)
                 props.pendingNewKeyword = kwd
               end
      )
    }
end

--[[
  Build the Recents view
]]
local function buildRecentView(f, context, fc)
    return f:view {
        width = DIALOG_WIDTH,
        height = 26,
        createGrid(f, context, RECENTLY_USED_PFX, fc, 
                   function(kwd) 
                     applyKeywordToSelection(context, kwd)
                   end
        )
    }
end

--[[
    Main entry
]]
function UI.showEditor(context)
    LrFunctionContext.callWithContext('GBKeywordEditor', function(fc)
        LogService.append('showEditor: begin')

        context.recent = RecentlyUsed.new(10)
        context.toolkitId = context.toolkitId or 'com.gb.keywordeditor.dev2'
        RecentlyUsed.loadInto(context, PrefsService.loadRecent(context.toolkitId))
        context.allKeywordNames = KeywordService.getAllKeywordNames(context.catalog)
        LogService.append(string.format('showEditor: loaded %d keyword names', context.allKeywordNames and #context.allKeywordNames or 0))

        local f = LrView.osFactory()
        local bind = LrView.bind
        local props = LrBinding.makePropertyTable(fc)
        context.props = props

        props.recentVersion = 0
        props.suggestionsDismissed = false
        props.hasSuggestions = false
        props.showSuggestions = false
        props.debugText = ''
        props.showCreateField = false -- Hide edit field by default
        props.hideCreateField = true  -- Inverse of showCreateField
        props.createButtonState = 'create' -- 'create' or 'accept'
        -- Ensure the label is set before UI is built
        for i = 1, MAX_SUGGESTIONS do
            props[suggestionTitleKey(i)] = ''
        end

        loadRowsFromSelection(context)
        -- LogService.append(string.format('showEditor: rows=%d', context.rows and #context.rows or 0)

        -- dLogService.append('debug channel active')

--[[
    Beg Create Observers
]]
        props:addObserver('showCreateField', function()
            props.hideCreateField = not props.showCreateField
        end)

        props:addObserver('pendingNewKeyword', function()
          refreshSuggestions(context)
        end)
--[[
    End Create Observers
]]
        local content = f:column {
            spacing = f:control_spacing(),
            fill_horizontal = 1,

            f:group_box {
                title = 'Keywords',
                width = DIALOG_WIDTH,
                fill_horizontal = 1,
                buildRowsView(f, context),
            },
            -- Add the create row and button below the rows container and above Completion
            f:view {
              place = 'overlapping',
              -- Container 1: Only the 'Create Keyword' button, right-aligned
              f:view {
                  bind_to_object = context.props,
                  visible = LrView.bind('hideCreateField'),
                  fill_horizontal = 1,
                  f:row {
                      spacing = f:control_spacing(),
                      fill_horizontal = 1,
                      f:spacer { fill_horizontal = 1 },
                      f:push_button {
                          title = 'Add Keyword',
                          action = function()
                              local props = context.props
                              props.showCreateField = true
                              props.pendingNewKeyword = ''
                          end,
                      },
                  },
              },
              -- Container 2: Edit field and 'Accept' button, right-aligned and in a row
              f:view {
                  bind_to_object = context.props,
                  visible = LrView.bind('showCreateField'),
                  fill_horizontal = 1,
                  f:row {
                      spacing = f:control_spacing(),
                      fill_horizontal = 1,
                      f:spacer { 
                        fill_horizontal = 1
                      },
                      f:edit_field {
                          value = LrView.bind('pendingNewKeyword'),
                          width = 172,
                          immediate = true,
                          focus = true,
                      },
                      f:push_button {
                          title = 'Accept',
                          enabled = LrView.bind {
                              key = 'pendingNewKeyword',
                              bind_to = props,
                              transform = function(value, fromModel)
                                  -- value is the current content of props.pendingNewKeyword
                                  if value and #value > 2 then
                                      return true
                                  else
                                      return false
                                  end
                              end
                          },
                          action = function()
                              local props = context.props
                              local v = props.pendingNewKeyword or ''
                              if trim(v) ~= '' then
                                  context.rows[#context.rows + 1] = {
                                      count = '',
                                      keyword = trim(v),
                                      keywordRef = nil,
                                  }
                                  props.pendingNewKeyword = ''
                                  props.showCreateField = false
                                  applyKeywordToSelection(context, v)
                              end
                          end,
                      },
                      f:push_button {
                        title = 'Cancel',
                        action = function()
                          local props = context.props
                          props.pendingNewKeyword = ''
                          props.showCreateField = false                        
                        end,
                      },
                  },
              },
            },

            f:group_box {
                title = 'Completion',
                width = DIALOG_WIDTH,
                fill_horizontal = 1,
                buildSuggestionsView(f, context, fc),
            },

            f:separator { fill_horizontal = 1 },

            f:group_box {
                title = 'Recently Used Keywords',
                width = DIALOG_WIDTH,
                fill_horizontal = 1,
                buildRecentView(f, context, fc),
            },
        }

        refreshRecentlyUsed(context)

        local result = LrDialogs.presentModalDialog {
            title = 'GB Keyword Editor',
            contents = content,
            actionVerb = 'Close',
        }

        -- LogService.append(string.format('showEditor: dialog closed result=%s', tostring(result)))
        return result
    end)
end

return UI
