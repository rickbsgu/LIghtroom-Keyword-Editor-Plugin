local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local LogService = {}

local fh
local logPath = nil

function LogService.serialize(tbl, seen, indent)
    if type(tbl) ~= "table" then
        return string.format("%q", tostring(tbl))
    end
    seen = seen or {}
    if seen[tbl] then
        return '"<cycle>"'
    end
    seen[tbl] = true
    indent = indent or ''
    local result = "{\n"
    local nextIndent = indent .. "  "
    for k, v in pairs(tbl) do
        (function()
        local key
        if type(k) == "string" then
        --[[
            for _, v in ipairs {"_parent"} do
              local i, j = string.find(k, v)
              if i == 1 then return end
            end
        ]]

            key = string.format("[%q]", k)
        else
            key = "[" .. tostring(k) .. "]"
        end
        result = result .. nextIndent .. key .. " = " .. LogService.serialize(v, seen, nextIndent) .. ",\n"
        end)()
    end
    return result .. indent .. "}"
end

function LogService.timeStamp()
    if not logPath then return end
    -- Lightroom's Lua has os.date.
    local ts = os.date('!%Y-%m-%dT%H:%M:%SZ')
    fh:write(ts)
end

function LogService.open()
    if not logPath then return end
    local fh = io.open(logPath, 'w')
    fh:close()
    if not fh then return false end
end

function LogService.append(message)
    if not logPath then return end
    local outStr
    if type(message) ~= "table" then
        outStr = string.format("%q", tostring(message)) .. "\n"
    else
        outStr = logService.serialize(message)
    end
    local fh = io.open(logPath, 'a')
    fh:write(outStr)
    fh:close()
    return true
end

return LogService
