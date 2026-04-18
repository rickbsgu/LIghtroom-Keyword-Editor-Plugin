

return {
    -- Let Lightroom choose the appropriate SDK compatibility.
    -- (Hard-pinning versions can cause load failures across builds.)
    LrSdkVersion = 15.0,

    LrToolkitIdentifier = 'com.gb.keywordeditor',
    LrPluginName = 'GB Keyword Editor',

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
            title = 'Open GB Keyword Editor',
            file = 'OpenKeywordEditor.lua',
        },
    },

    -- LrPluginInfoProvider = 'PluginInfoProvider.lua',
}
