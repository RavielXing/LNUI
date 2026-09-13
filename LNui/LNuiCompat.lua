--[[------------------------------------------------------------
LNui API 兼容层（正式服 12.0 / 12.1）
------------------------------------------------------------
1) C_Item.GetItemInfo / C_Item.GetItemInfoInstant
   12.0 起返回结构化表（ItemInfo），旧写法按多返回值取值会拿到表，
   这里统一归一化为旧式多返回值，两种形态都能正确取数。
2) GetCVar / SetCVar / GetCVarBool
   12.0 起全局函数被 C_CVar 取代，这里统一走 C_CVar，
   缺失时回退旧全局函数，保证老客户端也能工作。
本文件必须位于 TOC 文件列表最前，供其余所有文件使用。
---------------------------------------------------------------]]

local CItemInfo = C_Item and C_Item.GetItemInfo
local CItemInfoInstant = C_Item and C_Item.GetItemInfoInstant

local function GetItemInfo(key)
    local a, b, c, d, e, f, g, h, i2, j, k, l, m
    if CItemInfo then
        a, b, c, d, e, f, g, h, i2, j, k, l, m = CItemInfo(key)
        if type(a) == "table" then
            return a.itemName, a.itemLink, a.itemQuality, a.itemLevel, a.itemMinLevel,
                   a.itemType, a.itemSubType, a.itemStackCount, a.itemEquipLoc,
                   a.itemTexture, a.itemSellPrice, a.classID, a.subclassID
        end
        return a, b, c, d, e, f, g, h, i2, j, k, l, m
    end
    if GetItemInfo then
        return GetItemInfo(key)
    end
end

local function GetItemInfoInstant(key)
    local a, b, c, d, e, f, g
    if CItemInfoInstant then
        a, b, c, d, e, f, g = CItemInfoInstant(key)
        if type(a) == "table" then
            return a.itemID, a.itemType, a.itemSubType, a.itemEquipLoc,
                   a.itemIcon, a.classID, a.subclassID
        end
        return a, b, c, d, e, f, g
    end
    if GetItemInfoInstant then
        return GetItemInfoInstant(key)
    end
end

local function GetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    return GetCVar(name)
end

local function SetCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        return C_CVar.SetCVar(name, value)
    end
    return SetCVar(name, value)
end

local function GetCVarBool(name)
    if C_CVar and C_CVar.GetCVarBool then
        return C_CVar.GetCVarBool(name)
    end
    return GetCVarBool(name)
end

LNuiCompat = {
    GetItemInfo = GetItemInfo,
    GetItemInfoInstant = GetItemInfoInstant,
    GetCVar = GetCVar,
    SetCVar = SetCVar,
    GetCVarBool = GetCVarBool,
}
