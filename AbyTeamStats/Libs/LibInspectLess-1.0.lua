local MAJOR, MINOR = "LibInspectLess-1.0", tonumber(("$Rev: 99915 $"):match("(%d+)"))
local after40300 = select(4, GetBuildInfo())>40200
local issecretvalue, issecrettable = issecretvalue, issecrettable
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local AceTimer = LibStub:GetLibrary("AceTimer-3.0")

local function safeCompareGUID(guidA, guidB)
	if not guidA or not guidB then
		return false
	end
	local secretA = issecretvalue(guidA)
	local secretB = issecretvalue(guidB)
	if secretA ~= secretB then
		return false
	end
	return guidA == guidB
end

lib.events = lib.events or  LibStub("CallbackHandler-1.0"):New(lib)
lib.frame = lib.frame or CreateFrame("Frame", MAJOR.."_Frame")

LibInspectLessInterval = 0.5
LibInspectLessTimeout = 1.0 --观察超时的间隔
LibInspectLessDebug = false

SlashCmdList["INSPECTLESS"] = function(msg)
	if not msg or msg=="" then
		DEFAULT_CHAT_FRAME:AddMessage("InspectLess: Interval = "..LibInspectLessInterval, 1, 1, 0)
	elseif strlower(msg)=="debug" then
		LibInspectLessDebug = not LibInspectLessDebug
		DEFAULT_CHAT_FRAME:AddMessage("InspectLess: Debug = "..tostring(LibInspectLessDebug), 1, 1, 0)
	elseif tonumber(msg) and tonumber(msg)>0.1 then
		LibInspectLessInterval = tonumber(msg)
		DEFAULT_CHAT_FRAME:AddMessage("InspectLess: Interval = "..tonumber(msg), 1, 1, 0)
	end
end
SLASH_INSPECTLESS1 = "/inspectless";
SLASH_INSPECTLESS2 = "/lil";
SLASH_INSPECTLESS3 = "/libinspectless";

local waiting = 0 --两次观察之间间隔
local timeout = 0 --观察无返回结果
local BlockingAllForNextManual = false
local ManualCalling = false
local ShowResumeMessage = false
local InspectLessLastGUID = nil  --上次的观察人员，如果上次的观察和目前的不一样，间隔到了将自动观察, 如果一样，应该判断是否READY，如果已经READY了，最好再发一次READY消息
local InspectOtherRealmWarned = false

function lib:debug(msg, r, g, b)
	if LibInspectLessDebug then DEFAULT_CHAT_FRAME:AddMessage(tostring(msg), r or 0.5, g or 0.5, b or 0.5) end
end

local f = lib.frame
f:UnregisterAllEvents()
f:RegisterEvent("ADDON_LOADED");
f:RegisterEvent("INSPECT_READY");
f:SetScript("OnEvent", function(self, event, ...)
	return lib[event](lib, ...)
end)

--用来触发 InspectLess_Next 的Updater, 用来控制观察间隔
f:SetScript("OnUpdate", function(self,elapsed)
	if timeout > 0 then
		timeout = timeout - elapsed
		if timeout <=0 then
			InspectLessLastGUID = nil
			lib.unit = nil
			lib.guid = nil
			if elapsed < LibInspectLessTimeout then --登录的第一个时间很长
				lib:debug("timeout, fire InspectLess_Next");
				lib.events:Fire("InspectLess_Next", false, true)
			end
		end
		--waiting和timeout都是在真正触发NotifyInspect之后设置的，由于timeout比waiting大，所以timeout的时候waiting肯定是0
	end

	if waiting > 0 then
		waiting = waiting - elapsed
		if waiting<=0 and (BlockingAllForNextManual or ShowResumeMessage) then
			ShowResumeMessage = false
		end

		if waiting<=0 then
			lib:debug("end waiting")
			local locked = (lib.unit or lib.guid) and not lib.ready
			if locked then
			end
			InspectLessLastGUID = nil
			lib:debug("fire InspectLess_Next");
			lib.events:Fire("InspectLess_Next", lib.ready, false)
		end
	end
end)

-- 修复：不再直接hook全局NotifyInspect和ClearInspectPlayer
-- 改为提供SafeNotifyInspect方法供插件调用
-- 这样可以避免污染全局函数，防止taint传播到ActionButton

lib.origins = lib.origins or {}
lib.origins["NotifyInspect"] = NotifyInspect
lib.origins["ClearInspectPlayer"] = ClearInspectPlayer

-- 安全的观察函数，供插件调用（替代直接调用NotifyInspect）
function lib:SafeNotifyInspect(unit, isManual)
	local pass = false
	isManual = isManual or false

	if isManual then
		if waiting > 0 then
			BlockingAllForNextManual = true
			lib:debug("manual inspecting blocked.");
			return false
		else
			pass = true
		end
	else
		if waiting > 0 then
			return false
		else
			if not BlockingAllForNextManual then
				InspectLessLastGUID = UnitGUID(unit)
				pass = true
			else
				return false
			end
		end
	end

	if pass then
		waiting = LibInspectLessInterval
		lib.fail = false
		lib.ready = false
		lib.done = false
		lib.origins["ClearInspectPlayer"]()
		lib.unit = unit
		lib.name = UnitName(unit)
		lib.guid = UnitGUID(unit)
		lib.manual = isManual

		timeout = LibInspectLessTimeout
		lib.origins["NotifyInspect"](unit)
		if not after40300 then lib.CheckInspectItems(lib.guid) end

		if isManual then BlockingAllForNextManual = false end

		local unitName = 'not exists'
		if(UnitExists(unit)) then
			local name = UnitName(unit)
			if(name) then unitName = name end
		end
		lib:debug((isManual and "manual" or "addon").." inspecting done. "..unitName);
		return true
	end
	return false
end

-- 为了兼容旧代码，仍然提供IsNotBlocking等方法
function lib:IsNotBlocking()
	return waiting <=0 and not BlockingAllForNextManual
end

-- 手动设置ManualCalling标志（供兼容使用）
function lib:SetManualCalling(manual)
	ManualCalling = manual
end

-- 兼容旧API：直接调用NotifyInspect（不推荐，会绕过频率限制）
function lib:NotifyInspect(unit)
	return self:SafeNotifyInspect(unit, false)
end

local r={}
local CoreScheduleBucket = CoreScheduleBucket or function(t,o,a,i)
	if not AceTimer then return end
	if r[t]then AceTimer:CancelTimer(r[t])end
	local tt=AceTimer:ScheduleTimer(function(...)r[t]=nil a(...)end, o, i)
	r[t]=tt
	return tt
end

--循环检查玩家的装备是否已经获取到
function lib.CheckInspectItems(guid)
	local unit = lib:FindUnit(guid)
	if unit then
		local done = lib:GetInspectItemLinks(unit)
		if done then
			lib.done = true
			lib:debug("fired ItemReady, "..unit);
			lib.events:Fire("InspectLess_InspectItemReady", unit, lib.guid, lib.ready)
		else
			CoreScheduleBucket("LibInspectLessChecker", 0.1, lib.CheckInspectItems, guid)
		end
	else
		lib.fail = true
		if lib.unit then
			lib:debug("fired ItemFail, "..lib.unit);
			lib.events:Fire("InspectLess_InspectItemFail", lib.unit, lib.guid, lib.ready)
		end
	end
end

function lib:INSPECT_READY(guid)
	timeout = 0
	self.ready = true
	self:debug("fired InspectReady "..guid);
	self.events:Fire("InspectLess_InspectReady", lib:FindUnit(guid), guid, lib.done);
	if after40300 then lib.CheckInspectItems(guid) end --4.3幻化的问题
end

function lib:ADDON_LOADED(addon)
	if addon=="Blizzard_InspectUI" then
		f:UnregisterEvent("ADDON_LOADED");
		-- 修复：使用hooksecurefunc安全地hook，避免污染
		if InspectPaperDollFrame_SetLevel then
			hooksecurefunc("InspectPaperDollFrame_SetLevel", function()
				if InspectFrame.unit then
					local _, class = UnitClass(InspectFrame.unit);
					if class and RAID_CLASS_COLORS[class] then
						-- 原始函数已经由hooksecurefunc调用，这里不需要额外操作
					end
				end
			end)
		end
	end
end

function lib:FindUnit(guid)
	local function safeCompare(unit, guid)
		return safeCompareGUID(UnitGUID(unit), guid)
	end

	if lib.unit and safeCompare(lib.unit, guid) then
		return lib.unit
	elseif InspectFrame and InspectFrame:IsVisible() and InspectFrame.unit and safeCompare(InspectFrame.unit, guid) then
		return InspectFrame.unit
	else
		if IsInRaid() then
			for i=1, GetNumGroupMembers() do
				if safeCompare("raid"..i, guid) then
					return "raid"..i
				end
			end
		elseif IsInGroup() and not IsInRaid() then
			for i=1, GetNumSubgroupMembers() do
				if safeCompare("party"..i, guid) then
					return "party"..i
				end
			end
		else
			if safeCompare("player", guid) then return "player" end
			if safeCompare("target", guid) then return "target" end
			if safeCompare("focus", guid) then return "focus" end
		end
	end
end

function lib:GetInspectItemLinks(unit)
	local done = true
	for i=1, 17 ,1 do
		if GetInventoryItemTexture(unit, i) then
			local link = GetInventoryItemLink(unit, i)
			if not link then
				done = false
			else
				local found, _, gem1,gem2,gem3,gem4 = link:find("item:%d+:%d*:(%d*):(%d*):(%d*):(%d*):")
				if found then
					if gem1~="0" and gem1~="" and not C_Item.GetItemGem(link, 1) then done = false end
					if gem2~="0" and gem2~="" and not C_Item.GetItemGem(link, 2) then done = false end
					if gem3~="0" and gem3~="" and not C_Item.GetItemGem(link, 3) then done = false end
					if gem4~="0" and gem4~="" and not C_Item.GetItemGem(link, 4) then done = false end
				end
			end
		end
	end
	return done
end

function lib:GetUnit()
	local u = lib.unit
	if u and safeCompareGUID(lib.guid, UnitGUID(u)) and UnitIsVisible(u) and UnitIsConnected(u) and CanInspect(u) and UnitClass(u) then
		return u
	end
end

function lib:GetGUID()
	return lib.guid
end

function lib:IsReady()
	return lib.ready
end

function lib:IsDone()
	return lib.done
end

function lib:IsFail()
	return lib.done
end
