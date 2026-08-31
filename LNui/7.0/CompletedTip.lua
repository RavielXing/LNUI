local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind =
      hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind

local function onSetHyperlink(self, link)
    local type, id = string.match(link,"^(%a+):(%d+)")
    if not type or not id then return end
    if type == "quest" then
        if C_QuestLog.IsQuestFlaggedCompleted(id) then
            self:AddDoubleLine(LOCALE_zhCN and "你的进度：" or "你的進度：", LOCALE_zhCN and "已完成" or "已完成", 255,255,0, 0, 1, 0)
        else
            self:AddDoubleLine(LOCALE_zhCN and "你的进度：" or "你的進度：", LOCALE_zhCN and "未完成" or "未完成", 255,255,0, 1, 0, 0)
        end
        self:Show()
    elseif type == "achievement" then
        local id, name, points, completed, month, day, year = GetAchievementInfo(id)
        if completed then
            self:AddDoubleLine(LOCALE_zhCN and "你的进度：" or "你的進度：", format(LOCALE_zhCN and "完成于%d/%02d/20%d" or "完成於%d/%02d/20%d", month, day, year), 255,255,0, 0, 1, 0)
        else
            self:AddDoubleLine(LOCALE_zhCN and "你的进度：" or "你的進度：", LOCALE_zhCN and "进行中" or "進行中", 255,255,0, 1, 0, 0)
        end
        self:Show()
    end

end

local function hookScripts()
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
    hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)
end

--想办法在TipTac后面调用
CoreRegisterEvent("INIT_COMPLETED", { INIT_COMPLETED = hookScripts })
