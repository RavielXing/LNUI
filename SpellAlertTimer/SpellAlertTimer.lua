-- SpellAlertTimer by CN-无尽之海-简繁丶 (32655163@qq.com)
-- 未经允许请不要抄袭或复制 谢谢
-- Please do not copy or plagiarize without permission. Thank you.

local addonName, ns = ...
if not DoesTemplateExist("CustomAuraContainerTemplate") then return end

-- 调试模式：默认关闭，不持久化（每次 reload 自动重置）
ns.Debug = false

-- 法术 ID 映射：暴雪提供的SPELL_ID可能不是实际SPELL_ID 需要映射到实际SPELL_ID才能正确显示倒计时
local SPELL_ALIAS = {
	[1277420] = 263725,	--奥法-节能施法1层
	[1277421] = 263725,	--奥法-节能施法2层
	[1277422] = 263725,	--奥法-节能施法3层
	[126084]  = 44544,	--冰法-寒冰指2层
	[361519]  = { 369299, 392268 ,359618}, --龙人-精华迸发2层（奶龙=369299 / 增辉=392268 / 湮灭=359618）
	[1256579] = false,  --奶龙-麦林色拉的祝福不需要显示

}

ns.cdTexts = {}
local slots = {}
local size = SpellActivationOverlayFrame:GetSize()

-- 方向指示：左(1/7)往左为负、右(2/8)往右为正；具体大小由 DB.hOffset 控制
local SIDE_DIR = {
	[1] = -1,
	[7] = -1,
	[2] = 1,
	[8] = 1,
}

-- 计算水平偏移（像素）：方向 × DB.hOffset
local function GetSideOffset(position)
	local dir = SIDE_DIR[position]
	if not dir then return 0 end
	return dir * (SpellAlertTimerDB.hOffset or 5)
end

local function GetOrCreateContainer(spellID, position, scale, overlay)
	local key = spellID .. "-" .. position .. "-" .. scale
	if ns.Debug then print(key) end

	local container = slots[key]
	if not container then
		local filter = SPELL_ALIAS[spellID]
		if filter == false then
			return  -- 该法术标记为不需要显示，直接过滤掉不创建
		end
		-- 构造候选法术ID集合（支持单个ID，或一组ID如 {369299, 392268}）
		local includeSet
		if type(filter) == "table" then
			includeSet = {}
			for _, id in pairs(filter) do includeSet[id] = true end
		else
			includeSet = { [filter or spellID] = true }
		end

		container = CreateFrame("AuraContainer", nil, SpellActivationOverlayFrame, "CustomAuraContainerTemplate")
		container.overlaySpellID = spellID
		container.overlayRef = overlay
		container.position = position
		container.scale = scale
		container:AddAuraGroup("cd", "HELPFUL|PLAYER", {
			maxFrameCount = 1,
			candidateFilters = { includeSpellIDs = includeSet },
			initializeFrame = function(btn)
				btn:SetSize(size, size)
				btn:SetMouseMotionEnabled(false)
				local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
				cd:SetAllPoints(btn)
				cd:SetDrawSwipe(false)
				cd:SetDrawBling(false)
				cd:SetDrawEdge(false)
				cd:SetHideCountdownNumbers(false)
				cd:SetCountdownMillisecondsThreshold(10)
				local cdText = cd:GetCountdownFontString()
				if cdText then
					cdText:SetFontHeight(SpellAlertTimerDB.scale * scale)
					btn.overlayScale = scale
					ns.cdTexts[btn] = cdText
				end
				btn:SetDurationCooldown(cd)
			end,
		})
		container:SetUnit("player")
		slots[key] = container
	end
	local sideOffset = GetSideOffset(position)
	container:ClearAllPoints()
	container:SetPoint("CENTER", overlay, "CENTER", sideOffset * scale, 0)
	container:Show()
end

hooksecurefunc(SpellActivationOverlayFrame, "ShowOverlay", function(self, spellID, texturePath, position, scale, r, g, b)
	if not spellID then return end
	local overlay = self:GetOverlay(spellID, position)
	if not overlay then return end
	GetOrCreateContainer(spellID, position, scale, overlay)
end)

hooksecurefunc(SpellActivationOverlayFrame, "HideOverlays", function(self, spellID)
	for _, container in pairs(slots) do
		if container.overlaySpellID == spellID then
			container:Hide()
		end
	end
end)

hooksecurefunc(SpellActivationOverlayFrame, "HideAllOverlays", function(self)
	for _, container in pairs(slots) do
		container:Hide()
	end
end)

-- 供设置界面调用：实时更新所有倒计时文字缩放（DB 已在 Options 回调中保存）
function ns.UpdateScale(value)
	for btn, cdText in pairs(ns.cdTexts) do
		cdText:SetFontHeight(value * (btn.overlayScale or 1))
	end
end

-- 供设置界面调用：实时更新所有容器的水平偏移（DB 已在 Options 回调中保存）
function ns.UpdateOffset(value)
	for _, container in pairs(slots) do
		if container.overlayRef and container.overlayRef:IsShown() then
			local sideOffset = GetSideOffset(container.position)
			container:ClearAllPoints()
			container:SetPoint("CENTER", container.overlayRef, "CENTER", sideOffset * container.scale, 0)
		end
	end
end