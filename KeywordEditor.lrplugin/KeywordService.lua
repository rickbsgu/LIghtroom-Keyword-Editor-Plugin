local LrApplication = import 'LrApplication'

local KeywordService = {}

local function normalizeKeywordName(name)
    if not name then return '' end
    name = tostring(name)
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

local function countItems(listLike)
    if not listLike then return 0 end

    local okLen, len = pcall(function()
        return #listLike
    end)
    if okLen and type(len) == 'number' then
        return len
    end

    local count = 0
    for _, _ in ipairs(listLike) do
        count = count + 1
    end
    return count
end

function KeywordService.getAllKeywordNames(catalog)
    local out = {}

    local function walk(keyword)
        local name = keyword:getName()
        if name and name ~= '' then
            out[#out + 1] = name
        end
        local children = keyword:getChildren()
        if children then
            for _, child in ipairs(children) do
                walk(child)
            end
        end
    end

    local roots = catalog:getKeywords()
    if roots then
        for _, kw in ipairs(roots) do
            walk(kw)
        end
    end

    table.sort(out)
    return out
end

function KeywordService.findKeywordByName(catalog, name)
    name = normalizeKeywordName(name)
    if name == '' then return nil end

    local function walk(keyword)
        if not keyword then return nil end
        local kname = keyword:getName()
        if kname == name then
            return keyword
        end
        local children = keyword:getChildren()
        if children then
            for _, child in ipairs(children) do
                local found = walk(child)
                if found then return found end
            end
        end
        return nil
    end

    local roots = catalog:getKeywords()
    if roots then
        for _, root in ipairs(roots) do
            local found = walk(root)
            if found then return found end
        end
    end

    return nil
end

function KeywordService.searchKeywordNames(prefix, allNames, limit)
    prefix = normalizeKeywordName(prefix)
    if prefix == '' then return {} end

    limit = limit or 7
    local lowerPrefix = prefix:lower()

    local function isWordPrefixMatch(name)
        local lowerName = name:lower()
        local startPos = 1

        while true do
            local foundAt = lowerName:find(lowerPrefix, startPos, true)
            if not foundAt then
                return false
            end

            if foundAt == 1 then
                return true
            end

            local prev = lowerName:sub(foundAt - 1, foundAt - 1)
            if not prev:match('[%w]') then
                return true
            end

            startPos = foundAt + 1
        end
    end

    local matches = {}
    local seen = {}

    for _, name in ipairs(allNames) do
        if #matches >= limit then break end
        if name:lower():find(lowerPrefix, 1, true) == 1 then
            matches[#matches + 1] = name
            seen[name] = true
        end
    end

    for _, name in ipairs(allNames) do
        if #matches >= limit then break end
        if not seen[name] and isWordPrefixMatch(name) then
            matches[#matches + 1] = name
            seen[name] = true
        end
    end

    return matches
end

function KeywordService.addNewKeyword(catalog, name)
    name = normalizeKeywordName(name)
    if name == '' then return nil end

    local catalog = LrApplication.activeCatalog()
    local kw = KeywordService.findKeywordByName(catalog, name)
    if kw then return kw end

    catalog:withWriteAccessDo('Create Keyword', function()
        kw = catalog:createKeyword(name, {}, true, nil, true)
    end)

    return kw
end

function KeywordService.applyKeywordToPhotos(catalog, keyword, photos)
    if not keyword or not photos or #photos == 0 then return end

    catalog:withWriteAccessDo('Apply Keyword', function()
        for _, photo in ipairs(photos) do
            photo:addKeyword(keyword)
        end
    end)
end

function KeywordService.removeKeywordFromPhotos(catalog, keyword, photos)
    if not keyword or not photos or #photos == 0 then return end

    catalog:withWriteAccessDo('Remove Keyword', function()
        for _, photo in ipairs(photos) do
            photo:removeKeyword(keyword)
        end
    end)
end

function KeywordService.countPhotosWithKeyword(catalog, keyword_obj)
    if not keyword_obj then return 0 end
    local photos = keyword_obj:getPhotos()
    return countItems(photos)
end

function KeywordService.countPhotosWithKeywordViaCatalogFind(catalog, keyword_obj)
    return KeywordService.countPhotosWithKeyword(catalog, keyword_obj)
end

--[[
  Get the keyword counts for the entire catalog

  args:
    catalog: the catalog
    names: list of names
    returns: object of counts keyed by names
]]
function KeywordService.getCatalogKeywordCountsByName(catalog, names)
    local countsByName = {}
    if not catalog or type(names) ~= 'table' or #names == 0 then
        return countsByName
    end

    local targetNames = {}
    for _, name in ipairs(names) do
        local normalized = normalizeKeywordName(name)
        if normalized ~= '' then
            targetNames[normalized] = true
            countsByName[normalized] = 0
        end
    end

    -- recurse down children
    local function walk(keyword_obj)
        if not keyword_obj then return end

        local name = normalizeKeywordName(keyword_obj:getName())
        if targetNames[name] then
            local photos = keyword_obj:getPhotos()
            if photos then
                countsByName[name] = (countsByName[name] or 0) + countItems(photos)
                      -- append to the count, if already counted. Otherwise start from 0
            end
        end
        -- recurse through all of the keyword heirarchy
        local children = keyword_obj:getChildren()
        if children then
            for _, child in ipairs(children) do
                walk(child)
            end
        end
    end

    -- this is the traversal root
    local roots = catalog:getKeywords()
    if roots then
        for _, root in ipairs(roots) do
            walk(root)
        end
    end

    return countsByName
end

function KeywordService.countPhotosWithKeywordName(catalog, name)
    name = normalizeKeywordName(name)
    if name == '' then return 0 end

    local countsByName = KeywordService.getCatalogKeywordCountsByName(catalog, { name })
    return countsByName[name] or 0
end

--[[
   
   Returns { names = {..sorted..}, countsByName = { [name] = nSelectedPhotosWithKeyword } }
]]
function KeywordService.getKeywordDataForPhotos(photos)
    local countsByName = {}
    local keywordByName = {}
    if not photos or #photos == 0 then
        return { names = {}, countsByName = countsByName, keywordByName = keywordByName }
    end

    local catalog = LrApplication.activeCatalog()
    local selectedSet = {}
    for _, p in ipairs(photos) do
        local id = p.localIdentifier
        if id then
            selectedSet[id] = true
        end
    end

    local function walk(keyword)
        local name = normalizeKeywordName(keyword:getName())
        local photosWithKw = keyword:getPhotos()
        if photosWithKw then
            local n = 0
            for _, p in ipairs(photosWithKw) do
                local id = p.localIdentifier
                if id and selectedSet[id] then
                    n = n + 1
                end
            end
            if n > 0 and name ~= '' then
                countsByName[name] = n
                keywordByName[name] = keyword
            end
        end

        local children = keyword:getChildren() -- if has child keywords, recurse down
        if children then
            for _, child in ipairs(children) do
                walk(child)
            end
        end
    end

    -- recursion base
    local roots = catalog:getKeywords()
    if roots then
        for _, kw in ipairs(roots) do
            walk(kw)
        end
    end

    local names = {}
    for name, _ in pairs(countsByName) do
        names[#names + 1] = name
    end
    table.sort(names)
    return { names = names, countsByName = countsByName, keywordByName = keywordByName }
end

return KeywordService
