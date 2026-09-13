-- 冒险指南查看套装原属性小插件，https://bbs.nga.cn/read.php?tid=47453558，## Author: 彭佳欣

local setsFixHooked = false

local function FixEncounterJournal()
    if not EncounterJournal then
        return
    end

    -- 防止重复 Hook（局部变量，不再写入全局表）
    if setsFixHooked then
        return
    end

    setsFixHooked = true

    EncounterJournal:HookScript("OnShow", function(self)
        if self.Tabs then
            PanelTemplates_SetAllTabsShown(self, true)
            PanelTemplates_SetNumTabs(self, #self.Tabs)
        end
    end)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", FixEncounterJournal)
