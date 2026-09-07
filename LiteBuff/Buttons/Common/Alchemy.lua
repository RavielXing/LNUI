------------------------------------------------------------
-- Alchemy.lua
-- 合剂 + 磨刀石/油，使用公共ConsumableWheelButton
------------------------------------------------------------

local _, addon = ...

-- 合剂列表：银星/金星
local FLASK_ENTRIES = {
    { id = 241321, quality = "silver" }, -- 萨拉斯抗性合剂(银星)
    { id = 241320, quality = "gold" },   -- 萨拉斯抗性合剂(金星)
    { id = 241327, quality = "silver" }, -- 破碎残阳合剂(银星)
    { id = 241326, quality = "gold" },   -- 破碎残阳合剂(金星)
    { id = 241323, quality = "silver" }, -- 魔导师合剂(银星)
    { id = 241322, quality = "gold" },   -- 魔导师合剂(金星)
    { id = 241325, quality = "silver" }, -- 血骑士合剂(银星)
    { id = 241324, quality = "gold" },   -- 血骑士合剂(金星)
}

-- 磨刀石与油列表：银星/金星
local OIL_STONE_ENTRIES = {
    { id = 243735, quality = "silver" }, -- 黎明之油(银星)
    { id = 243736, quality = "gold" },   -- 黎明之油(金星)
    { id = 243733, quality = "silver" }, -- 萨拉斯凤凰之油(银星)
    { id = 243734, quality = "gold" },   -- 萨拉斯凤凰之油(金星)
    { id = 243737, quality = "silver" }, -- 私运者的附魔之锋(银星)
    { id = 243738, quality = "gold" },   -- 私运者的附魔之锋(金星)
    { id = 237367, quality = "silver" }, -- 辉耀平衡石(银星)
    { id = 237369, quality = "gold" },   -- 辉耀平衡石(金星)
    { id = 237370, quality = "silver" }, -- 辉耀磨刀石(银星)
    { id = 237371, quality = "gold" },   -- 辉耀磨刀石(金星)
}

local function GetQualityAtlas(itemID)
    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo then
        local info = C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
        if info and info.iconInventory then
            return info.iconInventory
        end
    end
    local link = select(2, C_Item.GetItemInfo(itemID))
    if link then
        local fullAtlas = link:match("|A:([^|]+)|a")
        if fullAtlas then
            return fullAtlas:match("^[^:]+")
        end
    end
    return nil
end

local function UpdateQualityMark(btn, entry)
    if not btn.icon.qualityTex then
        local tex = btn.icon:CreateTexture(nil, "OVERLAY")
        tex:SetSize(36, 36)
        tex:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", -5, 5)
        tex:SetDrawLayer("OVERLAY", 7)
        btn.icon.qualityTex = tex
    end
    local tex = btn.icon.qualityTex
    local atlas = GetQualityAtlas(entry.id)
    if atlas then
        tex:SetAtlas(atlas, false)
        tex:Show()
    else
        tex:Hide()
    end
end

addon.CreateConsumableWheelButton("CommonAlchemyFlask", "合剂", FLASK_ENTRIES, UpdateQualityMark)
addon.CreateConsumableWheelButton("CommonAlchemyStoneOil", "磨刀石与油", OIL_STONE_ENTRIES, UpdateQualityMark)
