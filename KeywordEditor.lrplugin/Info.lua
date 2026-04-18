

return {
    LrSdkVersion = 15.0,

    LrToolkitIdentifier = 'com.gb.keywordeditor',
    LrPluginName = 'LR Keyword Editor',

    files = {
      "Info.lua",
      "Debug.lua",
      "PrefsService.lua",
      "OpenKeywordEditor.lua",
      "LogService.lua",
      "KeywordService.lua",
      "LibraryMenuItems.lua",
      "RecentlyUsed.lua",
      "UI.lua",

    },

    LrLibraryMenuItems = {
        {
            title = 'Open LR Keyword Editor',
            file = 'OpenKeywordEditor.lua',
        },
    },
}
