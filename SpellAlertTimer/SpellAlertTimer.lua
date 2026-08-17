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
	[126084]  = 44544,	--冰法-寒冰指2层右边
	[361519]  = { 369299, 392268 ,359618}, --龙人-精华迸发2层（奶龙=369299 / 增辉=392268 / 湮灭=359618）
	[1256579] = false,  --奶龙-麦林色拉的祝福不需要显示
	[128654] = 114255,	--戒律牧-圣光涌动2层右边

}

-- 互斥组：同一组内两个槽位互斥显示，不管哪个触发都隐藏另一个
local EXCLUSIVE_PAIRS = {
	{ "114255-1-1", "198069-1-1" },  -- 戒律牧左边：圣光涌动 ↔ 阴暗面之力
	{ "128654-2-1", "198069-2-1" },  -- 戒律牧右边：圣光涌动2层 ↔ 阴暗面之力
}

-- 由互斥组构建“隐藏某法术时需恢复显示的对手 key”映射
local RESTORE_BY_SPELL = {}
for _, pair in ipairs(EXCLUSIVE_PAIRS) do
	local a, b = pair[1], pair[2]
	local aSpell = tonumber(a:match("^(%d+)"))
	local bSpell = tonumber(b:match("^(%d+)"))
	if aSpell then
		RESTORE_BY_SPELL[aSpell] = RESTORE_BY_SPELL[aSpell] or {}
		table.insert(RESTORE_BY_SPELL[aSpell], b)
	end
	if bSpell then
		RESTORE_BY_SPELL[bSpell] = RESTORE_BY_SPELL[bSpell] or {}
		table.insert(RESTORE_BY_SPELL[bSpell], a)
	end
end

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
					-- 初始化时（按钮尚未被禁止）用 GetFont 获取原字体并缓存，避免运行时读取触发 Forbidden 报错
					local fontFile = cdText:GetFont()
					btn.fontFile = fontFile
					cdText:SetFont(fontFile, SpellAlertTimerDB.scale * scale, SpellAlertTimerDB.outline or "OUTLINE")
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
	container:SetPoint("CENTER", overlay, "CENTER", sideOffset * scale, 0)
	container:Show()

	-- 互斥组：同一组内不管哪个触发都隐藏另一个（圣光涌动/阴暗面之力同位置冲突）
	for _, pair in ipairs(EXCLUSIVE_PAIRS) do
		local a, b = pair[1], pair[2]
		if key == a then
			if slots[b] then slots[b]:Hide() end
		elseif key == b then
			if slots[a] then slots[a]:Hide() end
		end
	end
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
			container:ClearAllPoints()
		end
	end

	-- 隐藏后显示互斥对手（光环容器自动判断光环是否存在，不存在则不显示）
	for _, rivalKey in ipairs(RESTORE_BY_SPELL[spellID] or {}) do
		if slots[rivalKey] then slots[rivalKey]:Show() end
	end
end)

hooksecurefunc(SpellActivationOverlayFrame, "HideAllOverlays", function(self)
	for _, container in pairs(slots) do
		container:Hide()
	end
end)

-- 供设置界面调用：实时更新所有倒计时文字缩放（DB 已在 Options 回调中保存）
-- 用初始化时缓存的字体文件（btn.fontFile），避免运行时 GetFont；pcall 保护 Forbidden 状态下的 SetFont
function ns.UpdateScale(value)
	for btn, cdText in pairs(ns.cdTexts) do
		pcall(function()
			cdText:SetFont(btn.fontFile, value * (btn.overlayScale or 1), SpellAlertTimerDB.outline or "OUTLINE")
		end)
	end
end

-- 供设置界面调用：实时更新所有倒计时文字的描边
function ns.UpdateOutline(value)
	for btn, cdText in pairs(ns.cdTexts) do
		pcall(function()
			cdText:SetFont(btn.fontFile, SpellAlertTimerDB.scale * (btn.overlayScale or 1), value or "")
		end)
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