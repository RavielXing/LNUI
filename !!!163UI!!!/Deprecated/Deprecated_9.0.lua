

ABY_BD_TPL = BackdropTemplateMixin and "BackdropTemplate" or nil

-- 把template替换成需要加BackdropTemplate的
CreateFrameAby = function(type, name, parent, template)
    local backdropTpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    if not template or template == "" then
        template = backdropTpl
    else
        template = (backdropTpl and backdropTpl .. "," or "") .. template
    end
    return CreateFrame(type, name, parent, template)
end

function AbyBackdrop(frame)
    if BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
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

--GetQuestLogIndexByID = C_QuestLog.GetLogIndexForQuestID

--[[------------------------------------------------------------
9.1.5
---------------------------------------------------------------]]
if not BACKDROP_TOOLTIP_16_16_5555 then
    BACKDROP_TOOLTIP_16_16_5555 = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    };

    BACKDROP_TOOLTIP_8_8_1111 = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileEdge = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    };

    BACKDROP_TOOLTIP_0_16_5555 = {
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        tileEdge = true,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    };
end

--oGlow TinyInspect TradeskillInfo
MAX_GUILDBANK_SLOTS_PER_TAB = MAX_GUILDBANK_SLOTS_PER_TAB or 98;
NUM_SLOTS_PER_GUILDBANK_GROUP = NUM_SLOTS_PER_GUILDBANK_GROUP or 14;

TOOLTIP_BACKDROP_STYLE_DEFAULT = TOOLTIP_BACKDROP_STYLE_DEFAULT or {
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },

	backdropBorderColor = TOOLTIP_DEFAULT_COLOR,
	backdropColor = TOOLTIP_DEFAULT_BACKGROUND_COLOR,
};



