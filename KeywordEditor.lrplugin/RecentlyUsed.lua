local KeywordService = require('KeywordService')

local RecentlyUsed = {}

function RecentlyUsed.new(maxItems)
    return {
        maxItems = maxItems or 10,
        items = {}, -- { { name=string, clicks=number } }
    }
end

function RecentlyUsed.loadInto(context, items)
    local model = context.recent
    model.items = {}
    if type(items) ~= 'table' then return end

    for _, item in ipairs(items) do
        if type(item) == 'table' and type(item.name) == 'string' then
            local name = item.name
            local clicks = tonumber(item.clicks) or 0
            if name ~= '' then
                local kw = KeywordService.findKeywordByName(context.catalog, name)
                if (kw) then
                  model.items[#model.items + 1] = { name = name, clicks = clicks }
                  -- only load keywords that exist in catalog
                end
            end
        end
    end

    while #model.items > model.maxItems do
        table.remove(model.items)
    end
end

function RecentlyUsed.exportItems(model)
    local out = {}
    for _, item in ipairs(model.items) do
        out[#out + 1] = { name = item.name, clicks = item.clicks or 0 }
    end
    return out
end

local function findIndex(model, name)
    for i, item in ipairs(model.items) do
        if item.name == name then return i end
    end
    return nil
end

function RecentlyUsed.bump(model, name)
    if not name or name == '' then return end

    local idx = findIndex(model, name)
    if idx then
        model.items[idx].clicks = (model.items[idx].clicks or 0) + 1
    else
        table.insert(model.items, { name = name, clicks = 1 })
    end

    table.sort(model.items, function(a, b)
        local ac = a.clicks or 0
        local bc = b.clicks or 0
        if ac == bc then
            return a.name:lower() < b.name:lower()
        end
        return ac > bc
    end)

    while #model.items > model.maxItems do
        table.remove(model.items)
    end
end

function RecentlyUsed.getNames(model)
    local out = {}
    for _, item in ipairs(model.items) do
        out[#out + 1] = item.name
    end
    return out
end

return RecentlyUsed
