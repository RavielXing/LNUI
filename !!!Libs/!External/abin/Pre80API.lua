local C_UnitAuras = C_UnitAuras
local C_Map = C_Map
local ipairs = ipairs
local tinsert = tinsert
local unpack = unpack
local strfind = strfind or string.find

local LIBNAME = "Pre80API"
local VERSION = 1.08

local lib = _G[LIBNAME]
if lib and lib.version >= VERSION then return end

if not lib then
	lib = {}
end

_G[LIBNAME] = lib
_G["Pre80API"] = lib

lib.version = VERSION

-- 12.0 起 UnitAura/UnitBuff/UnitDebuff 全局函数已被移除，统一改用 C_UnitAuras。
-- 返回序列与旧 UnitAura 保持一致：
-- name, rank(nil), icon, count, dispelType, duration, expirationTime, source,
-- isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossAura,
-- castByPlayer, nameplateShowAll, timeMod, isFromPlayerOrPlayerPet, isFromAreaEffect
local function AuraDataToReturns(data)
	if not data then
		return
	end

	return data.name, nil, data.icon, data.applications, data.dispelType,
		data.duration, data.expirationTime, data.sourceUnit,
		data.isStealable, data.nameplateShowPersonal, data.spellId, data.canApplyAura,
		data.isBossAura, data.castByPlayer, data.nameplateShowAll, data.timeMod,
		data.isFromPlayerOrPlayerPet, data.isFromAreaEffect
end

-- 补全隐含的类型过滤：UnitBuff 隐含 HELPFUL，UnitDebuff 隐含 HARMFUL，
-- 与旧版 UnitBuff/UnitDebuff 的 filter 语义一致（filter 可以是 "PLAYER" 等附加条件）。
local function NormalizeFilter(filter, impliedType)
	if impliedType then
		if type(filter) ~= "string" or not strfind(filter, impliedType) then
			filter = type(filter) == "string" and (filter .. "|" .. impliedType) or impliedType
		end
	end

	return filter
end

local function GetAuraData(unit, aura, filter, impliedType)
	filter = NormalizeFilter(filter, impliedType)

	if type(aura) == "number" then
		return C_UnitAuras.GetAuraDataByIndex(unit, aura, filter)
	end

	return C_UnitAuras.GetAuraDataBySpellName(unit, aura, filter)
end

function lib.UnitAura(unit, aura, filter)
	return AuraDataToReturns(GetAuraData(unit, aura, filter))
end

function lib.UnitBuff(unit, aura, filter)
	return AuraDataToReturns(GetAuraData(unit, aura, filter, "HELPFUL"))
end

function lib.UnitDebuff(unit, aura, filter)
	return AuraDataToReturns(GetAuraData(unit, aura, filter, "HARMFUL"))
end

function lib.GetCurrentMapAreaID()
	local mapID = C_Map.GetBestMapForUnit("player")
	if type(mapID) == "number" and mapID > 0 then
		return mapID
	end
end

local CONTINENT_IDS = { 12, 13, 101, 113, 424, 572, 619, 876 }
function lib.GetMapContinents()
	local result = {}
	for _, id in ipairs(CONTINENT_IDS) do
		local info = C_Map.GetMapInfo(id)
		if info then
			tinsert(result, info.name)
		end
	end
	return unpack(result)
end

function lib.GetCurrentMapContinent()
	local mapID = C_Map.GetBestMapForUnit("player")
	if type(mapID) ~= "number" or mapID < 1 then
		return 0
	end

	-- 沿父地图链向上查找，直到大陆层级（替代已废弃的 MapUtil.GetMapParentInfo）
	for _ = 1, 32 do
		local info = C_Map.GetMapInfo(mapID)
		if not info then
			return 0
		end

		if info.mapType == Enum.UIMapType.Continent then
			return info.mapID, info.name
		end

		mapID = info.parentMapID
	end

	return 0
end

function lib.GetMapNameByID(id)
	if type(id) == "number" then
		local info = C_Map.GetMapInfo(id)
		if info then
			return info.name
		end
	end
end

lib.GetContinentName = lib.GetMapNameByID
