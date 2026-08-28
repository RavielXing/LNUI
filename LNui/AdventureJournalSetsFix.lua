-- 冒险指南查看套装原属性小插件，https://bbs.nga.cn/read.php?tid=47453558，## Author: 彭佳欣

local function FixEncounterJournal()
    if not EncounterJournal then
        return
    end

    -- 防止重复 Hook
    if EncounterJournalSetsFixHooked then
        return
    end

    EncounterJournalSetsFixHooked = true

    EncounterJournal:HookScript("OnShow", function(self)
        if self.Tabs then
            PanelTemplates_SetAllTabsShown(self, true)
            PanelTemplates_SetNumTabs(self, #self.Tabs)
        end
    end)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", FixEncounterJournal)