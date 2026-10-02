------------------------------------------------------------
-- Core.lua
--
-- Abin
-- 2011/11/13
--
-- 主体: 命名空间、默认值DEFAULTS、按钮注册、法术名缓存、事件分发
------------------------------------------------------------

local type = type
local tinsert = tinsert
local select = select
local pairs = pairs
local ipairs = ipairs
local format = format
local strbyte = strbyte
local tostring = tostring
local wipe = wipe
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local UnitName = UnitName
local UnitClass = UnitClass
local GetActiveSpecGroup = GetActiveSpecGroup
local GetRealmName = GetRealmName
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local InCombatLockdown = InCombatLockdown
local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras

-- 12.1 secret值统一处理：secret值当nil/默认值，避免把secret数据泄漏给上层逻辑
local function SafeAuraValue(v, default)
	if issecretvalue and issecretvalue(v) then
		return default
	end
	return v ~= nil and v or default
end

local addonName, addon = ...
_G["LiteBuff"] = addon
addon.version = "2.1-opt"

-- 默认值都在这, 改默认只改这一处
-- 面板(CfgLiteBuff/Options)与运行时(Main)都读这里, 别在别处再写一份
addon.DEFAULTS = {
	layout = {
		growh = true,            -- 横向排列(否则竖排)
		gap = 4,                 -- 图标间隔(163UI面板)
		spacing = 4,             -- 按钮间距(原生面板的滑条)
		scale = 80,              -- 百分比, 80=80%
		anchor = { "BOTTOM", 600, 150 }, -- 主框第一次创建时的锚点
	},
	behavior = {
		lock = false,            -- 锁定框体
		percharpos = true,       -- 位置按角色独立保存
		simpletip = false,       -- 简短提示
	},
	alerts = {
		alertMissing = false,    -- 中央缺失Buff提示
		missingLock = true,      -- 锁定提示位置
		iconSize = 42,           -- 提示图标边长
		iconSpacing = 52,        -- 提示图标间距
		pos = { x = 300, y = 0 },-- 提示框默认位置(存档里没位置记录时用)
	},
	-- 滚轮按钮默认选中第几项(存档里没记录时用)
	scrollIndex = 1,

	-- 每个按钮一条: true=默认禁用, false=默认显示, 按职业分组方便改
	-- 只对存档里没记录的按钮生效, 不覆盖用户设置
	-- 按钮各职业都会创建(显不显示由它自己的Requirement决定), 所以这里按职业列全
	-- 用 button.key 而不是显示标题: 标题随语言变, key 与语言无关
	-- 新按钮必须在这里补一条: 没有默认值的设置不算完整, harness会拿embeds.xml的加载清单双向核对
	disabledButtons = {
		common = {                              -- 全职业
			CommonRefreshment     = true,       -- 恢复
			TalentSwitch          = true,       -- 切换天赋
			IntelliMount          = false,      -- 智能坐骑
			CommonFood            = false,      -- 食物
			LightforgedRune       = false,      -- 强化符文
			CommonAlchemyFlask    = false,      -- 合剂
			CommonAlchemyStoneOil = false,      -- 磨刀石与油
		},
		WARRIOR     = {                         -- 姿态/怒吼
			WarriorStances        = true,
			WarriorShouts         = false,
		},
		PALADIN     = {                         -- 圣光道标/信仰道标/姿态
			PaladinBeaconOfLight  = true,
			PaladinBeaconOfLight2 = true,
			PALADINStances        = true,
		},
		HUNTER      = {                         -- 陷阱/宠物/功能技能
			HunterTraps           = true,
			HunterPets            = false,
			HUNTERFunction        = false,
		},
		DEATHKNIGHT = {                         -- 宠物/功能技能/加速技能
			DeathKnightGhoul      = false,
			DeathKnightHornOfWinter = false,
			DeathKnightPresences  = false,
		},
		DRUID       = {                         -- 变形形态/印记/传送
			DruidShapeShift       = true,
			DruidMarkOfTheWild    = false,
			DRUIDPORTAL           = false,
		},
		MAGE        = {                         -- 奥术智慧/传送门/造餐/缓落
			MageArcaneBrilliance  = false,
			MagePortal            = false,
			MageConjureRefreshment = false,
			MageFunction          = false,
		},
		PRIEST      = {                         -- 耐力/暗影形态/漂浮术
			PriestFortitude       = false,
			ShadowStance          = false,
			PRIESTFunction        = false,
		},
		ROGUE       = {                         -- 伤害型/功能型毒药
			RoguePoison1          = false,
			RoguePoison2          = false,
		},
		WARLOCK     = {                         -- 召唤恶魔/治疗石/法阵/诅咒
			WarlockPets           = false,
			WarlockHealthstone    = false,
			DemonicCircle         = false,
			WARLOCKCurses         = true,
		},
		MONK        = {                         -- 功能技能/传送/传送门/雕像
			MONKFUNCTION          = false,
			MONKTeleport          = false,
			MONKPORTAL            = false,
			MonkOxStatue          = true,
		},
		SHAMAN      = {                         -- 图腾/天怒/水上行走/护盾/武器灌魔
			SHAMANTotems          = true,
			ShamanBuff            = true,
			WaterWalk             = true,
			ShamanShields1        = false,
			SHAMANWeapon          = false,
		},
		EVOKER      = { EvokerBuff           = false }, -- 守护巨龙之力
		DEMONHUNTER = { DEMOHUNTERFunction   = true },  -- 禁锢
	},
}

-- 把按职业分组的默认开关摊平成 key -> true/false, 供面板与初始化使用
-- 非本职业的按钮本来就不会创建, 所以这里不需要按职业过滤
function addon:GetDefaultDisabled()
	local flat = {}
	for _, group in pairs(self.DEFAULTS.disabledButtons) do
		for key, disabled in pairs(group) do
			flat[key] = disabled and true or false
		end
	end
	return flat
end

-- 按钮当前该不该禁用: 存档里有记录听存档, 没记录用默认表
function addon:IsButtonDisabled(key)
	local saved = self:LoadData("disabledb", key)
	if saved ~= nil then
		return saved and true or false
	end
	return self:GetDefaultDisabled()[key] and true or false
end

-- 用户设置: 正本永远在插件自己的存档里, 面板(163UI/原生)只是入口
-- 键 -> 存哪个表 + 对应DEFAULTS里的位置
local SETTINGS = {
	growh        = { store = "db",     path = "layout.growh" },
	gap          = { store = "db",     path = "layout.gap" },
	simpletip    = { store = "db",     path = "behavior.simpletip" },
	percharpos   = { store = "db",     path = "behavior.percharpos" },
	alertMissing = { store = "db",     path = "alerts.alertMissing" },
	missingLock  = { store = "db",     path = "alerts.missingLock" },
	lock         = { store = "chardb", path = "behavior.lock" },
}

-- 读设置: 存档里有记录听存档, 没记录落到默认值
-- 别直接LoadData: 那样默认值只在"nil恰好等于false"时才碰巧对
function addon:GetSetting(key)
	local info = SETTINGS[key]
	if not info then return end
	local saved = self:LoadData(info.store, key)
	if saved ~= nil then
		return saved
	end
	local group, name = info.path:match("^(%a+)%.(%a+)$")
	local defaults = group and self.DEFAULTS[group]
	return defaults and defaults[name]
end

-- 写设置: 只落插件存档, 表现由调用方自己刷新
function addon:SetSetting(key, value)
	local info = SETTINGS[key]
	if info then
		self:SaveData(info.store, key, value)
	end
end

-- 缩放: 存档里是百分比(80=80%), 面板上显示倍数
function addon:GetScale()
	local scale = self:LoadData("db", "scale")
	if type(scale) ~= "number" or scale < 20 or scale > 300 then
		return self.DEFAULTS.layout.scale
	end
	return scale
end

function addon:SetScale(scale)
	if type(scale) ~= "number" or scale < 20 or scale > 300 then
		scale = self.DEFAULTS.layout.scale
	end
	self:SaveData("db", "scale", scale)
	self:ApplyScale(scale)
end

-- 只把缩放应用到框体, 不动存档(首装落地用它, 这样没动过的项一直"跟随默认")
function addon:ApplyScale(scale)
	if CoreUISetScale then
		-- 163UI在的时候用它那个: 缩放时保持左上角位置不变
		CoreUISetScale(self.frame, scale / 100)
	else
		self.frame:SetScale(scale / 100)
	end
end

function addon:GetSpacing()
	local spacing = self:LoadData("db", "spacing")
	if type(spacing) ~= "number" or spacing < 0 then
		return self.DEFAULTS.layout.spacing
	end
	return spacing
end

-- 163UI那边的选项名(插件这边的键 -> 面板里的var)
local CFG_VARS = {
	growh        = { var = "growh" },
	gap          = { var = "gap" },
	simpletip    = { var = "simpletip" },
	percharpos   = { var = "percharpos" },
	alertMissing = { var = "alertMissing" },
	missingLock  = { var = "missingLock" },
	lock         = { var = "locked" },
}

-- 读163UI那边存的选项值; 没有163UI(单体环境)或没有这个选项就nil
local function ReadCfgVar(var)
	if not U1GetCfgValue then return nil end
	return U1GetCfgValue("LiteBuff", var, true)
end

-- 163UI记的主框位置(数组: 1=left 2=top 3=宽 4=高, 6..10=锚点);
-- 它的frames机制在插件加载时会恢复一次, 但这里只拿它当"方案换过位置"的信号
local function ReadCfgFramePos()
	local frames = U1DB and U1DB.frames
	return frames and frames["LiteBuffFrame"]
end

local function CopyFlat(t)
	local out = {}
	if type(t) == "table" then
		for k, v in pairs(t) do out[k] = v end
	end
	return out
end

local function SameFlat(a, b)
	local na, nb = 0, 0
	for k, v in pairs(a) do
		na = na + 1
		if b[k] ~= v then return false end
	end
	for _ in pairs(b) do nb = nb + 1 end
	return na == nb
end

-- 跟163UI那边的对账: 它的方案(配置文件)换过, 就把它那套值抄进插件存档。
-- 正本始终是插件存档, 这里只认"163UI那边变过"这个信号。
-- 快照存在db.u1mirror: 没有快照(新装/刚删过存档)一律不抄, 这样"删存档=回默认"永远成立。
local function SyncFromCfgMirror()
	if not U1GetCfgValue or type(addon.db) ~= "table" then return end

	local mirror = addon.db.u1mirror
	if type(mirror) ~= "table" then
		-- 第一次见: 只记快照, 一个字都不抄
		mirror = {}
		addon.db.u1mirror = mirror
		for key, data in pairs(CFG_VARS) do
			mirror[key] = ReadCfgVar(data.var)
		end
		local scale = ReadCfgVar("scale")
		mirror.scale = type(scale) == "number" and scale or nil
		mirror.disabled = CopyFlat(ReadCfgVar("disabled"))
		return
	end

	local changed = false
	for key, data in pairs(CFG_VARS) do
		local now = ReadCfgVar(data.var)
		if now ~= mirror[key] then
			mirror[key] = now
			-- 对面清成默认(nil)时就把记录也清掉, 跟着默认走
			addon:SetSetting(key, now)
			changed = true
		end
	end

	local scale = ReadCfgVar("scale")
	if type(scale) == "number" and scale ~= mirror.scale then
		mirror.scale = scale
		addon:SetScale(scale * 100)
	end

	-- 每个按钮的开关是一张表, 逐项对
	local nowTable = CopyFlat(ReadCfgVar("disabled"))
	local oldTable = mirror.disabled or {}
	if not SameFlat(nowTable, oldTable) then
		mirror.disabled = nowTable
		for key, checked in pairs(nowTable) do
			if checked ~= addon:IsButtonDisabled(key) then
				addon:SetButtonDisabled(key, checked)
				changed = true
			end
		end
		for key in pairs(oldTable) do
			if nowTable[key] == nil then
				-- 对面这项没了(退回默认): 我们的记录也清掉
				addon:SetButtonDisabled(key, nil)
				changed = true
			end
		end
	end

	-- 主框位置: 163UI那边记的是left/top, 抄成我们那套锚点
	local nowPos = CopyFlat(ReadCfgFramePos())
	if not SameFlat(nowPos, mirror.frames or {}) then
		mirror.frames = nowPos
		if type(nowPos[1]) == "number" and type(nowPos[2]) == "number" then
			addon:SavePosition("framePos", "TOPLEFT", "BOTTOMLEFT", nowPos[1], nowPos[2])
		end
	end

	if changed and addon.RefreshLiteBuffs then
		addon:RefreshLiteBuffs()
	end
end

-- 主框位置只认插件存档: 有记录就摆过去, 没记录摆回默认锚点。
-- 163UI的方案换了位置会由 SyncFromCfgMirror 抄进存档, 这里不直接听它的。
function addon:SettleFramePosition()
	local frame = self.frame
	if not frame then return end

	local saved = self:LoadPosition("framePos")
	frame:ClearAllPoints()
	if saved then
		frame:SetPoint(saved.point or "BOTTOM", UIParent, saved.relativePoint or "BOTTOM",
			saved.x or 0, saved.y or 0)
	else
		local anchor = self.DEFAULTS.layout.anchor
		frame:SetPoint(anchor[1], UIParent, anchor[1], anchor[2], anchor[3])
	end
end

-- 按钮禁用/启用: Disable()/Enable()只在状态真跳变时才走OnEnable脚本,
-- 登录时按钮都是"从没被禁用过"的, 得显式InvokeMethod把事件和属性挂上
function addon:ApplyButtonDisabled(button, disabled)
	if not button then return end
	if disabled then
		button:Disable()
	elseif button:IsEnabled() then
		button:InvokeMethod("OnEnable")
	else
		button:Enable()
	end
end

-- 面板改按钮开关的唯一入口: 存显式值(用户动过的按钮不再跟默认走), 状态立即落地
-- disabled传nil = 清掉记录, 回到默认表那一档(方案把这项退回默认时用)
function addon:SetButtonDisabled(key, disabled)
	if disabled ~= nil then
		disabled = disabled and true or false
		self:SaveData("disabledb", key, disabled)
	else
		self:SaveData("disabledb", key, nil)
		disabled = self:GetDefaultDisabled()[key] and true or false
	end
	self:ApplyButtonDisabled(self:GetButton(key), disabled)
end

local actionButtons = {}
local groupLastDead = {}
addon.actionButtons = actionButtons

-- 登录后统一落地一遍: 默认表的禁用和玩家自己的禁用都在这里生效(重载不会再把按钮放出来)
-- 得写在 actionButtons 声明之后: local在声明之前读不到, 会读到同名全局(nil)
local function ApplyButtonDisabledStates()
	local defaults = addon:GetDefaultDisabled()
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		local saved = addon:LoadData("disabledb", button.key)
		local disabled
		if saved ~= nil then
			-- 存档优先: 这里不能写成(saved and true or false) or defaults[key],
			-- 存档里显式放开是false, 会被or的兜底又按默认禁掉
			disabled = saved and true or false
		else
			disabled = defaults[button.key]
		end
		addon:ApplyButtonDisabled(button, disabled)
	end
end

-- 按钮间距: 除第一个外, 每个按钮的y偏移等于间距
function addon:SetButtonSpacing(spacing)
	for i = 2, #actionButtons do
		local button = actionButtons[i]
		button:SetAttribute("spacing", spacing)
		if button:IsShown() then
			local point, relativeTo, relativePoint, xOffset, yOffset = button:GetPoint(1)
			if yOffset ~= -spacing then
				button:ClearAllPoints()
				button:SetPoint(point, relativeTo, relativePoint, xOffset, -spacing)
			end
		end
	end
end

-- 老版本的选项值存在163UI自己的存档里(litebuff/xxx), 这一版起正本收到插件存档,
-- 那份老值一律不管: 插件这边没记录就是默认值, 谁也不许从163UI往回抄(不然"删存档=回默认"就不成立)
local function ApplyDefaults()
	addon:ApplyScale(addon:GetScale())
	addon:SetButtonSpacing(addon:GetSpacing())
end

-- Cache for spell name -> spell ID conversion
local spellNameToIdCache = {}
addon._spellNameToIdCache = spellNameToIdCache
local CACHE_MAX_SIZE = 500

-- 满了淘汰最老的, 不要整表清空(那样每满一次就集中重算一遍)
local spellNameOrder = {}

local function RememberSpellName(name, id)
	if spellNameToIdCache[name] == nil then
		spellNameOrder[#spellNameOrder + 1] = name
	end
	spellNameToIdCache[name] = id
	while #spellNameOrder > CACHE_MAX_SIZE do
		local oldest = table.remove(spellNameOrder, 1)
		if spellNameToIdCache[oldest] ~= nil then
			spellNameToIdCache[oldest] = nil
		end
	end
end

function addon:CreateActionButton(key, category, title, duration, ...)
	local button = self.templates.CreateActionButton(key, category, title, duration, ...)
	if button then
		tinsert(actionButtons, button)
		if(self._163_AddToggleOption) then
			self:_163_AddToggleOption(button)
		end

		-- 按钮基本都是插件文件加载期创建的, 那时存档还没就绪, 状态先不动,
		-- 等 ADDON_LOADED 之后由 ApplyButtonDisabledStates 统一落地;
		-- 之后再创建的按钮(比如物品扫描出来的)在这里就地定状态
		if self.disabledb then
			self:ApplyButtonDisabled(button, self:IsButtonDisabled(key))
		end

		return button
	end
end

function addon:GetNumButtons()
	return #actionButtons
end

function addon:GetButton(index)
	if type(index) == "string" then
		for _, button in ipairs(actionButtons) do
			if button.key == index then
				return button
			end
		end
	else
		return actionButtons[index]
	end
end

-- Player spells
local LPS = _G["LibPlayerSpells-1.0"]
function addon:PlayerHasSpell(spell)
	return LPS:PlayerHasSpell(spell)
end

function addon:PlayerHasTalent(talent)
	return LPS:PlayerHasTalent(talent)
end

function addon:PlayerHasGlyph(glyph)
	return LPS:PlayerHasGlyph(glyph)
end

-- Builds a spell list using given spell id and conflicts list
local LAG = _G["LibBuffGroups-1.0"]
function addon:BuildSpellList(spellList, spellId, group, ...)
	if not spellId then return end

	local spell = C_Spell.GetSpellInfo(spellId)
	if not spell then return end

	local icon = spell.iconID
	local spellName = spell.name
	if not spellName then return end

	local data = { id = spellId, spell = spellName, icon = icon }
	if type(spellList) == "table" then
		tinsert(spellList, data)
	end

	-- Cache name -> ID
	RememberSpellName(spellName, spellId)

	-- Build conflicts list
	local conflicts = {}
	local conflictsById = {}
	local conflictsCount = 0

	if type(group) == "string" then
		local similars = LAG:GetGroupAuras(group)
		if similars then
			for _, cid in pairs(similars) do
				if cid and cid ~= spellId then
					local cspell = C_Spell.GetSpellInfo(cid)
					if cspell and cspell.name ~= spellName then
						conflicts[cspell.name] = cspell.iconID
						conflictsCount = conflictsCount + 1
					end
					if cspell and cspell.name then
						RememberSpellName(cspell.name, cid)
					end
					conflictsById[cid] = true
				end
			end
		end
	elseif type(group) == "number" then
		for i = 1, select("#", group, ...) do
			local cid = select(i, group, ...)
			if type(cid) == "number" and cid ~= spellId then
				local cspell = C_Spell.GetSpellInfo(cid)
				if cspell and cspell.name ~= spellName then
					conflicts[cspell.name] = cspell.iconID
					conflictsCount = conflictsCount + 1
				end
				if cspell and cspell.name then
					RememberSpellName(cspell.name, cid)
				end
				conflictsById[cid] = true
			end
		end
	end

	if conflictsCount > 0 then
		data.conflicts = conflicts
	end
	if next(conflictsById) then
		data.conflictsById = conflictsById
	end

	return data
end

function addon:UpdateSpellListIcons(spellList)
	for _, data in ipairs(spellList) do
		if data.id then
			local spell = C_Spell.GetSpellInfo(data.id)
			if spell then
				data.icon = spell.iconID
			end
		end
	end
end

-- 法术名/ID 解析: 数字原样返回, 字符串走名字缓存(未命中查一次并记住)
-- 供 GetUnitBuffTimer 与模板(FindAura等)共用, 避免各处重复实现
function addon:ResolveSpellID(buff)
	if type(buff) == "number" then
		return buff
	end
	if type(buff) == "string" then
		local spellID = spellNameToIdCache[buff]
		if not spellID then
			local spell = C_Spell.GetSpellInfo(buff)
			if spell and spell.spellID then
				spellID = spell.spellID
				RememberSpellName(buff, spellID)
			end
		end
		return spellID
	end
end

-- Retrieves buff remain time - MEMORY OPTIMIZED for WoW 12.1
-- Uses GetAuraDataByIndex instead of GetUnitAuras to avoid allocating
-- massive aura tables on every single scan.
function addon:GetUnitBuffTimer(unit, buff, mine)
	if not unit or not buff then
		return
	end

	local spellID = self:ResolveSpellID(buff)

	if type(spellID) ~= "number" then
		return
	end

	-- Fast path: GetPlayerAuraBySpellID for player unit
	if unit == "player" then
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if aura then
			local sourceUnit = aura.sourceUnit
			if not mine or (type(sourceUnit) == "string" and not (issecretvalue and issecretvalue(sourceUnit)) and sourceUnit == "player") then
				return SafeAuraValue(aura.expirationTime, 0), SafeAuraValue(aura.applications, 1)
			end
		end
		return
	end

	-- Secret 状态下不要扫描其他单位的光环，避免报错
	if unit ~= "player" and C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
		return
	end

	-- Memory-efficient fallback: scan by index, zero table allocation
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
		if not aura then break end
		-- 解封 secret number，避免 taint 导致的比较错误
		local auraSpellId = aura.spellId
		if issecretvalue and issecretvalue(auraSpellId) then
			auraSpellId = nil
		else
			auraSpellId = tonumber(auraSpellId)
		end
		if auraSpellId and auraSpellId == spellID then
			if not mine then
				return SafeAuraValue(aura.expirationTime, 0), SafeAuraValue(aura.applications, 1)
			end
			local sourceUnit = aura.sourceUnit
			if type(sourceUnit) == "string" and not (issecretvalue and issecretvalue(sourceUnit)) and sourceUnit == "player" then
				return SafeAuraValue(aura.expirationTime, 0), SafeAuraValue(aura.applications, 1)
			end
		end
	end
end

function addon:GetGradientColor(number, threshold)
	local r, g = 1, 0
	if number and threshold and threshold > 0 then
		local percent = number / threshold
		if percent >= 0.5 then
			r, g = (1.0 - percent) * 2, 1
		else
			r, g = 1, percent * 2
		end
	end
	return r, g, 0
end

function addon:IsFormActive(form)
	for i = 1, GetNumShapeshiftForms() do
		local _, active, castable, spellId = GetShapeshiftFormInfo(i)
		if spellId and type(spellId) == "number" and not (issecretvalue and issecretvalue(spellId)) then
			local spell = C_Spell.GetSpellInfo(spellId)
			if spell and spell.name == form then
				return active
			end
		end
	end
end

function addon:GetColoredUnitName(unit)
	if not unit then return end
	local name = UnitName(unit)
	if issecretvalue and issecretvalue(name) then
		return UNKNOWNOBJECT
	end
	if not name then return end
	local class = select(2, UnitClass(unit))
	if issecretvalue and issecretvalue(class) then
		class = nil
	end
	local color = class and RAID_CLASS_COLORS[class]
	if color then
		name = format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
	end
	return name
end

function addon:IsGrouped()
	local count = GetNumGroupMembers()
	local group
	if IsInRaid() then
		group = "raid"
	elseif count > 0 then
		group = "party"
	end
	return group, count
end

-- Data access
local DATA_TABLES = { db = 1, chardb = 1, specdb = 1, disabledb = 1 }
local function GetDataTable(dataType)
	return DATA_TABLES[dataType] and addon[dataType]
end

function addon:LoadData(dataType, key)
	local data = GetDataTable(dataType)
	return data and data[key]
end

function addon:SaveData(dataType, key, value)
	local data = GetDataTable(dataType)
	if data then
		data[key] = value
		return 1
	end
end

--- 位置存档: 按角色独立(percharpos=true, 默认) 或 账号共用(false)
function addon:PositionDB()
	if not addon:GetSetting("percharpos") then
		return addon.db
	end
	return addon.chardb or addon.db
end

function addon:SavePosition(key, point, relativePoint, x, y)
	local pdb = addon:PositionDB()
	if pdb then
		pdb[key] = { point = point, relativePoint = relativePoint, x = x, y = y }
		return 1
	end
end

function addon:LoadPosition(key)
	local pdb = addon:PositionDB()
	local pos = pdb and pdb[key]
	if not pos and pdb ~= addon.db and addon.db then
		pos = addon.db[key]	-- 迁移: 之前存在账号级的老位置
	end
	return pos
end

local EVENTS_DEF = {
	UNIT_AURA = { method = "OnPlayerAura", arg1 = "player" },
	UNIT_INVENTORY_CHANGED = { method = "OnInventoryUpdate", arg1 = "player" },
	PLAYER_EQUIPMENT_CHANGED = { method = "OnInventoryUpdate", arg1 = "player" },
	BAG_UPDATE = { method = "OnBagUpdate" },
	BAG_UPDATE_COOLDOWN = { method = "OnBagUpdate" },
	PLAYER_TALENT_UPDATE = { method = "OnTalentUpdate" },
	UNIT_STATS = { method = "OnStatsUpdate", arg1 = "player" },
	RAID_ROSTER_UPDATE = { method = "OnRosterUpdate" },
	UNIT_PET = { method = "OnPlayerPet", arg1 = "player" },
	PLAYER_TOTEM_UPDATE = { method = "OnPlayerPet" },
}

local inCombat
local methodPool = {}

local function FireAllEvents()
	for _, data in pairs(EVENTS_DEF) do
		methodPool[data.method] = 1
	end
end

local function NotifyButtons(method)
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		-- 禁用状态只隐藏的话，内部仍会被NotifyButtons驱动；
		-- 这里跳过禁用按钮，让“禁用”真正关闭功能并省掉无效扫描
		if not button:GetAttribute("disabled") then
			button:InvokeMethod(method, inCombat)
		end
	end
end

local function OnTalentSwitch()
	local db = addon.chardb.talents
	if type(db) ~= "table" then
		db = {}
		addon.chardb.talents = db
	end
	local talent = GetActiveSpecGroup()
	if type(db[talent]) ~= "table" then
		db[talent] = {}
	end
	addon.specdb = db[talent]
	NotifyButtons("OnTalentSwitch")
end

local updateElapsed = 0
local function Frame_OnUpdate(self, elapsed)
	updateElapsed = updateElapsed + elapsed
	if updateElapsed > 0.2 then
		updateElapsed = 0
		for method in pairs(methodPool) do
			NotifyButtons(method)
			methodPool[method] = nil
		end
	end
end

local spellFire = {}
LPS:HookObject(spellFire)

function spellFire:OnSpellsChanged()
	-- 法术书/天赋变动常与SPELLS_CHANGED等事件成串到来,
	-- 塞进节流池合并, 0.2秒内只全量刷一遍, 不在事件里立即重算
	methodPool.OnSpellUpdate = 1
end

--------------------------------------------
-- Addon main frame
--------------------------------------------

local frame = CreateFrame("Frame", "LiteBuffFrame", UIParent, "SecureFrameTemplate")
addon.frame = frame
frame:SetSize(50, 50)
local anchor = addon.DEFAULTS.layout.anchor
frame:SetPoint(anchor[1], anchor[2], anchor[3])
frame:SetMovable(true)
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
-- 位置自己存(SettleFramePosition + framePos), 不走暴雪的SetUserPlaced,
-- 否则角色的layout-local.txt会跟着记一份, "删存档=回默认"就不成立了
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		self:UnregisterEvent(event)

		if type(LiteBuffDB) ~= "table" then
			LiteBuffDB = {}
		end
		addon.db = LiteBuffDB

		if not addon.db.v21 then
			wipe(addon.db)
			addon.db.v21 = 1
		end

		if type(LiteBuffCharDB) ~= "table" then
			LiteBuffCharDB = {}
		end
		addon.chardb = LiteBuffCharDB

		if type(addon.chardb.disabled) ~= "table" then
			addon.chardb.disabled = {}
		end

		addon.disabledb = addon.chardb.disabled

		SyncFromCfgMirror()

		ApplyDefaults()

		NotifyButtons("OnInitialize")

		-- 禁用状态放最后落地, 免得被禁用的按钮又走一遍初始化流程
		ApplyButtonDisabledStates()

		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

		for key in pairs(EVENTS_DEF) do
			self:RegisterEvent(key)
		end
		self:RegisterEvent("UNIT_HEALTH")

		OnTalentSwitch()
		self:SetScript("OnUpdate", Frame_OnUpdate)

	elseif event == "PLAYER_ENTERING_WORLD" then
		FireAllEvents()
		-- 读图瞬间法术/光环数据正在重流, 每次C_查询都是冷查询;
		-- OnEnterWorld塞进节流池, 与读图后成串到来的事件合并, 0.2秒内只跑一遍
		methodPool.OnEnterWorld = 1

	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = 1
		NotifyButtons("OnEnterCombat")

	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = nil
		FireAllEvents()
		NotifyButtons("OnLeaveCombat")
		Frame_OnUpdate(self, 1000)

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		if arg1 == 'player' then OnTalentSwitch() end

	else
		-- 队伍/团队变化时清理死亡状态缓存
		if event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
			wipe(groupLastDead)
		end

		-- 监听队友/团队成员的UNIT_AURA，否则队友死亡/被补buff后
		-- GROUP_AURA按钮不会刷新，仍显示缺少增益
		-- 先用首字符预筛(party/raid), 姓名板/目标等单位的aura事件不跑正则
		if event == "UNIT_AURA" and arg1 then
			local first = strbyte(arg1, 1)
			if (first == 112 or first == 114) and (arg1:match("^party%d+$") or arg1:match("^raid%d+$")) then
				methodPool.OnPlayerAura = 1
			end
		end

		-- 死亡/复活边界：WoW死亡时不一定触发UNIT_AURA，
		-- 用UNIT_HEALTH的存活/死亡跳变强制刷新一次
		-- 同样首字符预筛, 只关心party*/raid*(含player/pet, 与原逻辑一致)
		if event == "UNIT_HEALTH" and arg1 then
			local first = strbyte(arg1, 1)
			if first == 112 or first == 114 then
				local dead = UnitIsDeadOrGhost(arg1)
				if groupLastDead[arg1] ~= dead then
					groupLastDead[arg1] = dead
					methodPool.OnPlayerAura = 1
				end
			end
		end

		local data = EVENTS_DEF[event]
		if data then
			if not data.arg1 or data.arg1 == tostring(arg1) then
				methodPool[data.method] = 1
			end
		end
	end
end)

local _callbacks = {}
local _regen = 'PLAYER_REGEN_ENABLED'
local function onEvent(self, event, arg1)
	if InCombatLockdown() then return self:RegisterEvent(_regen) end
	if event == _regen then self:UnregisterEvent(_regen) end
	if event == 'PLAYER_SPECIALIZATION_CHANGED' and arg1 ~= 'player' then return end
	for f in next, _callbacks do
		pcall(f)
	end
end

local f = CreateFrame'Frame'
f:SetScript('OnEvent', onEvent)
f:RegisterEvent'LEARNED_SPELL_IN_SKILL_LINE'
f:RegisterEvent'PLAYER_SPECIALIZATION_CHANGED'

function addon:__163_OnSpellChanged(callback)
	_callbacks[callback] = true
	if IsLoggedIn() then
		pcall(callback)
	else
		f:RegisterEvent'PLAYER_LOGIN'
	end
end