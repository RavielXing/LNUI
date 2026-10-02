------------------------------------------------------------
-- MissingBuffAlert.lua
-- 缺失状态提示的显示层: 中央图标、定位框拖拽、发光、刷新与兜底ticker。
------------------------------------------------------------

local _, addon = ...
local GetTime = GetTime
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsDead = UnitIsDead
local UnitOnTaxi = UnitOnTaxi
local IsMounted = IsMounted
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local UIParent = UIParent
local GameTooltip = GameTooltip
local ICON_SIZE = addon.DEFAULTS.alerts.iconSize
local ICON_SPACING = addon.DEFAULTS.alerts.iconSpacing

-- 检测与数据在 MissingBuffEntries.lua(先加载), 从 addon.alertData 取
local alertData = addon.alertData
local MissingEntries, SpellName, GetIcon = alertData.GetEntries, alertData.SpellName, alertData.GetIcon
local FALLBACK_ICON = alertData.FallbackIcon

local function Enabled()
	return addon:GetSetting("alertMissing") and true or false
end

local function IsLocked()
	return addon:GetSetting("missingLock") and true or false
end

local function ShouldHide()
    if InCombatLockdown() then
        return true
    end
    if UnitIsDeadOrGhost("player") then
        return true
    end
    if UnitOnTaxi and UnitOnTaxi("player") then
        return true
    end
    if IsMounted and IsMounted() then
        return true
    end
    return false
end

local function ApplyCastToButton(b, id)
    if not id then
        b:SetAttribute("type", nil)
        b:SetAttribute("spell", nil)
        b:SetAttribute("macrotext", nil)
        b:SetAttribute("type1", nil)
        b:SetAttribute("spell1", nil)
        b:SetAttribute("macrotext1", nil)
        b.appliedCast = nil
    elseif not InCombatLockdown() then
        if id == 974 then
            -- 大地之盾可对队友施放：当前友方目标优先，没有则对自己
            local macrotext = '/cast [@target,help,nodead][@player] ' .. SpellName(974)
            b:SetAttribute("type", "macro")
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext", macrotext)
            b:SetAttribute("macrotext1", macrotext)
            b:SetAttribute("spell", nil)
            b:SetAttribute("spell1", nil)
        else
            local spell = SpellName(id)
            b:SetAttribute("type", "spell")
            b:SetAttribute("type1", "spell")
            b:SetAttribute("spell", spell)
            b:SetAttribute("spell1", spell)
            b:SetAttribute("macrotext", nil)
            b:SetAttribute("macrotext1", nil)
        end
        b.appliedCast = id
    end
end

local function SetupStateDriver(b)
    if not b.stateDriverRegistered then
        b.stateDriverRegistered = true
        RegisterStateDriver(b, "visibility", "[combat] hide; show")
    end
end

local frame = CreateFrame("Frame", "LiteBuffMissingAlertFrame", UIParent)
frame:SetFrameStrata("MEDIUM")
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    if not IsLocked() then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    addon:SavePosition("missingAlertPos", point, relativePoint, x, y)
end)
frame:Hide()

-- 解锁时显示的定位框，方便没有缺失提示时也能拖动位置
-- 起个名字方便排查: /run print(LiteBuffMissingDragFrame:IsShown())
local dragFrame = CreateFrame("Frame", "LiteBuffMissingDragFrame", UIParent)
dragFrame:SetSize(140, 34)
dragFrame:SetFrameStrata("HIGH")
dragFrame:SetMovable(true)
dragFrame:EnableMouse(true)
dragFrame:RegisterForDrag("LeftButton")
dragFrame:SetClampedToScreen(true)
local dragBg = dragFrame:CreateTexture(nil, "BACKGROUND")
dragBg:SetAllPoints()
dragBg:SetColorTexture(0, 0.8, 0, 0.4)
local dragLabel = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dragLabel:SetPoint("CENTER")
dragLabel:SetText("缺失Buff提示位置")
dragFrame:Hide()

local function SaveCurrentPosition(x, y)
    addon:SavePosition("missingAlertPos", "CENTER", "CENTER", x or 0, y or 0)
end

-- 默认位置跟别的默认设置一起放在 Core.lua 的 DEFAULTS.alerts 里
local DEFAULT_POS = addon.DEFAULTS.alerts.pos

-- 只摆提示容器; 定位框的位置由 LiteBuff_UpdateMissingDragFrame 一个人管
-- (两边都摆的话, 框会先回到图标中心再被拽到图标上方, 看起来就是在跳)
local function ApplySavedPosition()
    local pos = addon:LoadPosition("missingAlertPos")
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POS.x, DEFAULT_POS.y)
    end
end

-- 按位移搬, 不是把提示直接吸到框的位置: 框在图标上方时那样会让图标跳一下
local dragFromX, dragFromY
dragFrame:SetScript("OnDragStart", function(self)
    if not IsLocked() then
        self._dragging = true
        local px, py = UIParent:GetCenter()
        local cx, cy = self:GetCenter()
        dragFromX, dragFromY = cx - px, cy - py
        self:StartMoving()
    end
end)
dragFrame:SetScript("OnDragStop", function(self)
    self._dragging = nil
    self:StopMovingOrSizing()
    local px, py = UIParent:GetCenter()
    local cx, cy = self:GetCenter()
    local pos = addon:LoadPosition("missingAlertPos")
    local baseX = pos and pos.x or DEFAULT_POS.x
    local baseY = pos and pos.y or DEFAULT_POS.y
    local x = math.floor(baseX + (cx - px) - (dragFromX or 0) + 0.5)
    local y = math.floor(baseY + (cy - py) - (dragFromY or 0) + 0.5)
    SaveCurrentPosition(x, y)
    ApplySavedPosition()
    LiteBuff_UpdateMissingDragFrame()   -- 拖完立刻摆回该在的位置
end)

local function GetButtonGlowLib()
    if LibStub then
        return LibStub("LibButtonGlow-1.0", true)
    end
end

local function StartGlow(b)
    if not b or b._glowStarted then
        return
    end
    b._glowStarted = true
    local LBG = GetButtonGlowLib()
    if LBG and LBG.ShowOverlayGlow then
        LBG.ShowOverlayGlow(b)
        local ov = b.__LBGoverlay
        if ov then
            local w, h = b:GetSize()
            ov:SetSize(w * 1.8, h * 1.8)
            ov:SetPoint("TOPLEFT", b, "TOPLEFT", -w * 0.4, h * 0.4)
            ov:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", w * 0.4, -h * 0.4)
        end
        return
    end
    if not b._glowTex then
        b._glowTex = b:CreateTexture(nil, "OVERLAY")
        b._glowTex:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
        b._glowTex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        b._glowTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        b._glowTex:SetVertexColor(1, 0.9, 0.2, 1)
        b._glowTex:SetDrawLayer("OVERLAY", 1)
    end
    b._glowTex:Show()
end

local function StopGlow(b)
    if not b or not b._glowStarted then
        return
    end
    b._glowStarted = nil
    local LBG = GetButtonGlowLib()
    if LBG and LBG.HideOverlayGlow then
        LBG.HideOverlayGlow(b)
        return
    end
    if b._glowTex then
        b._glowTex:Hide()
    end
end

local icons = {}

local function UpdateDisplay(list)
    if #list == 0 then
        frame:Hide()
        LiteBuff_UpdateMissingDragFrame()   -- 提示没了, 框挪回中间
        return
    end

    local total = #list
    frame:SetSize(total * ICON_SPACING + 20, ICON_SIZE + 10)
    frame:Show()
    -- 图标一出来就把移动框挪到它们上方(解锁状态下), 别等ticker
    LiteBuff_UpdateMissingDragFrame()

    for i, entry in ipairs(list) do
        local b = icons[i]
        if not b then
            b = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
            b:SetSize(ICON_SIZE, ICON_SIZE)
            b:RegisterForClicks("AnyDown", "AnyUp")
            b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            SetupStateDriver(b)
            b:SetScript("OnEnter", function(self)
                if self.entryText then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:AddLine(self.entryText, 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            b:SetScript("OnMouseWheel", function(self, delta)
                if InCombatLockdown() then
                    return
                end
                local opts = self.entryOptions
                if not opts or #opts < 2 then
                    return
                end
                local idx = self.entryOptionIndex or 1
                idx = idx - delta
                if idx < 1 then
                    idx = #opts
                elseif idx > #opts then
                    idx = 1
                end
                self.entryOptionIndex = idx
                local id = opts[idx]
                self.entryCast = id
                ApplyCastToButton(self, id)
                local icon = GetIcon(id)
                if icon then
                    self.icon:SetTexture(icon)
                end
                local name = SpellName(id)
                if name and not self.fixedText then
                    self.entryText = name
                end
            end)
            b:RegisterForDrag("LeftButton")
            b:SetScript("OnDragStart", function()
                if not IsLocked() then
                    frame:StartMoving()
                end
            end)
            b:SetScript("OnDragStop", function()
                frame:StopMovingOrSizing()
                local point, _, relativePoint, x, y = frame:GetPoint(1)
                addon:SavePosition("missingAlertPos", point, relativePoint, x, y)
                ApplySavedPosition()
            end)
            icons[i] = b
        end
        SetupStateDriver(b)

        b:ClearAllPoints()
        b:SetPoint("CENTER", frame, "CENTER", (i - (total + 1) / 2) * ICON_SPACING, 0)
        local opts = entry.options
        if opts and #opts > 0 then
            local sameOptions = b.entryOptions and #b.entryOptions == #opts
            if sameOptions then
                for j = 1, #opts do
                    if b.entryOptions[j] ~= opts[j] then
                        sameOptions = false
                        break
                    end
                end
            end
            if sameOptions and b.entryOptionIndex then
                local idx = b.entryOptionIndex
                if idx < 1 then
                    idx = 1
                elseif idx > #opts then
                    idx = #opts
                end
                b.entryOptionIndex = idx
                local id = opts[idx]
                b.entryCast = id
                local name = SpellName(id)
                b.entryText = (entry.fixedText and entry.text) or name or entry.text
                b.icon:SetTexture(GetIcon(id) or entry.icon or FALLBACK_ICON)
            else
                b.entryOptions = opts
                b.entryOptionIndex = 1
                b.entryCast = opts[1]
                local name = SpellName(opts[1])
                b.entryText = (entry.fixedText and entry.text) or name or entry.text
                b.icon:SetTexture(GetIcon(opts[1]) or entry.icon or FALLBACK_ICON)
            end
        else
            b.entryOptions = nil
            b.entryOptionIndex = nil
            b.entryCast = entry.cast
            b.entryText = entry.text
            b.icon:SetTexture(entry.icon or FALLBACK_ICON)
        end
        b.fixedText = entry.fixedText
        ApplyCastToButton(b, b.entryCast)
        b:EnableMouse(true)
        pcall(StartGlow, b)
        b:Show()
    end

    for i = total + 1, #icons do
        local old = icons[i]
        if old then
            if old.stateDriverRegistered then
                UnregisterStateDriver(old, "visibility")
                old.stateDriverRegistered = nil
            end
            pcall(StopGlow, old)
            old:EnableMouse(false)
            old:Hide()
        end
    end
end

-- 进副本/换场景后先等几秒，避免角色光环/姿态还没就绪时误报缺失
local zoneSuppressUntil = 0

-- 重算并刷新提示(事件驱动 + 低频兜底共用)
-- 重算并刷新提示(事件驱动 + 低频兜底 + 配置回调共用)
-- 暴露成全局: CfgLiteBuff 的配置回调需要在勾选后立即刷新, 不能等兜底轮询
function LiteBuff_RefreshAlerts()
    -- 刚进副本/场景时等光环数据稳定再判断，避免插钥匙后误报
    if GetTime() < zoneSuppressUntil then
        return
    end
    if Enabled() and not ShouldHide() then
        UpdateDisplay(MissingEntries())
    elseif not InCombatLockdown() then
        -- 战斗中不能对受保护框架调 Hide(会报"界面行为失效"); 按钮自带 [combat] hide 状态驱动, 战斗里本就看不见
        frame:Hide()
    end
end
local RefreshAlerts = LiteBuff_RefreshAlerts

-- 事件驱动刷新做去抖合并: 读图/进本后 UNIT_AURA/SPELLS_CHANGED 等会成串到来,
-- 而每次MissingEntries都是几十次C_查询+建表, 逐条重算直接打满帧时间。
-- 0.3秒窗口内的一串事件只重算一次(配置回调走的LiteBuff_RefreshAlerts仍是即时)
local refreshPending = false
local function RequestRefresh()
	if refreshPending then
		return
	end
	refreshPending = true
	C_Timer.After(0.3, function()
		refreshPending = false
		RefreshAlerts()
	end)
end

-- 事件驱动: 状态一变立刻重算, 不再依赖高频轮询
-- 兜底: 万一有事件没覆盖到(buff自然到期等), 1秒轮询会补上(改造前是0.3秒无条件重算)
local alertEvents = CreateFrame("Frame")
alertEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
alertEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
alertEvents:RegisterEvent("UNIT_AURA")
alertEvents:RegisterEvent("UNIT_PET")
alertEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
alertEvents:RegisterEvent("SPELLS_CHANGED")
alertEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
alertEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
alertEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
alertEvents:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        zoneSuppressUntil = GetTime() + 3
        frame:Hide()
        -- 位置和定位框不能只靠兜底ticker维护(那是"万一漏了才补"的东西):
        -- ticker没跑起来的话, 就只剩"提醒图标出现"这条路径会摆框, 解锁后根本看不到框
        ApplySavedPosition()
        LiteBuff_UpdateMissingDragFrame()
        -- 抑制期一结束就立刻恢复, 不等兜底轮询
        C_Timer.After(3.1, function()
            if not InCombatLockdown() then
                RefreshAlerts()
            end
        end)
        return
    end
    if InCombatLockdown() then
        return
    end
    -- UNIT_AURA/UNIT_PET 只关心玩家自己, 别被队友/目标的aura刷爆
    if (event == "UNIT_AURA" or event == "UNIT_PET") and arg1 ~= "player" and arg1 ~= "pet" then
        return
    end
    RequestRefresh()
end)

-- 定位框显示/隐藏维护: 抽成函数, 配置一改可立即刷新(不必等ticker)
function LiteBuff_UpdateMissingDragFrame()
    if IsLocked() or ShouldHide() or InCombatLockdown() then
        dragFrame._dragging = nil   -- 拖到一半被锁定/进战斗打断的话, 标记不能留着
        dragFrame:Hide()
        return
    end
    -- 正在拖的话一个字都别动: ticker一秒跑一次, 会把手里拖着的框拽回去
    if dragFrame._dragging then
        return
    end
    -- 图标正在显示时把移动框抬到图标上方: 以前是干脆藏起来, 结果正缺Buff时解锁看不到框、也没法拖
    -- 也不能压在图标上, 会挡住点击(技能就按不出去了)
    -- 图标没显示时按存档坐标自己摆(UIParent坐标), 别锚在那个还没尺寸/还没定位的提示容器上——
    -- 锚过去的话框会"显示着但摆在没有位置的地方", 表现就是解锁后怎么都不出现
    dragFrame:ClearAllPoints()
    if frame:IsShown() then
        dragFrame:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    else
        local pos = addon:LoadPosition("missingAlertPos")
        dragFrame:SetPoint("CENTER", UIParent, "CENTER",
            (pos and pos.x) or DEFAULT_POS.x, (pos and pos.y) or DEFAULT_POS.y)
    end
    dragFrame:Show()
end

-- 兜底: 万一有事件没覆盖到(如buff自然到期没触发UNIT_AURA), 1秒轮询补上
-- (改造前是0.3秒无条件重算; 现在是事件即时 + 1秒兜底, 实测CPU可忽略)
local positionRestored = false
C_Timer.NewTicker(1, function()
    if not positionRestored then
        positionRestored = true
        ApplySavedPosition()
        -- 主框架(常驻按钮容器)位置: 跟163UI那边对账, 没记录就摆回默认锚点
        addon:SettleFramePosition()
    end
    LiteBuff_UpdateMissingDragFrame()
    RefreshAlerts()
end)
