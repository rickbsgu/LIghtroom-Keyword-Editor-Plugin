local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

local openEditor = require 'OpenKeywordEditor'

LrDialogs.message('GB Keyword Editor', 'Library menu callback fired (canary)', 'info')
LrTasks.startAsyncTask(function()
    openEditor()
end)
