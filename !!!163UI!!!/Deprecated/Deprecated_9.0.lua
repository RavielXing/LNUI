ABY_BD_TPL = "BackdropTemplate"

-- 把template替换成需要加BackdropTemplate的
CreateFrameAby = function(type, name, parent, template)
    if not template or template == "" then
        template = "BackdropTemplate"
    else
        template = "BackdropTemplate," .. template
    end
    return CreateFrame(type, name, parent, template)
end

function AbyBackdrop(frame)
    Mixin(frame, BackdropTemplateMixin)
end


GetCurrencyInfo = function(ID)
    local i = C_CurrencyInfo.GetCurrencyInfo(ID)
    --sig: name, amount, texturePath, earnedThisWeek, weeklyMax, totalMax, isDiscovered, quality = GetCurrencyInfo(824)
    if i then
        return i.name, i.quantity, i.iconFileID, i.quantityEarnedThisWeek, i.maxWeeklyQuantity, i.maxQuantity, i.discovered, i.quality
    end
end



AbyGetQuestsCompleted = function(tbl)
    tbl = tbl or {}
    local ids = C_QuestLog.GetAllCompletedQuestIDs()
    for _, questId in ipairs(ids or {}) do
        tbl[questId] = true
    end
    return tbl
end