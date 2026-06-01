local addonName, ns = ...

-- ========================================================================
-- 本地化
-- ========================================================================
ns.L = setmetatable({}, {
    __index = function(t, key) return key end
})

-- ========================================================================
-- 存档初始化
-- ========================================================================
local function MergeDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if target[k] == nil then target[k] = {} end
            MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    RoyMapGuideDB = RoyMapGuideDB or {}
    if ns.defaults then
        MergeDefaults(RoyMapGuideDB, ns.defaults)
    end

    -- 斜杠命令
    SLASH_RoyMapGuide1 = "/rmg"
    SlashCmdList["RoyMapGuide"] = function()
        if ns.categoryID then
            Settings.OpenToCategory(ns.categoryID)
        end
    end
end)
