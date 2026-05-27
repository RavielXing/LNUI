local _, SELFAQ = ...

local L = SELFAQ.L

-- 复制table的数据，而不是引用
SELFAQ.clone = function(org)
    local function copy(org, res)
        for k,v in pairs(org) do
            if type(v) ~= "table" then
                res[k] = v;
            else
                res[k] = {};
                copy(v, res[k])
            end
        end
    end
 
    local res = {}
    copy(org, res)
    return res
end

-- 合并两个数组
SELFAQ.merge = function(...)
    local tabs = {...}
    if not tabs then
        return {}
    end
    local origin = tabs[1]
    for i = 2,#tabs do
        if origin then
            if tabs[i] then
                for k,v in pairs(tabs[i]) do
                    table.insert(origin,v)
                end
            end
        else
            origin = tabs[i]
        end
    end
    return origin
end

-- 去掉重复的值
SELFAQ.diff = function( t1, t2 )
    local new = {}

    for i,v in ipairs(t1) do
        if not tContains(t2, v) then
            table.insert(new, v)
        end
    end

    return new
end

SELFAQ.reverseId = function( id )

    if id == nil then
        return 0,0
    end
    
    local order = math.floor(id/1000000)
    local rid = id%1000000

    return rid, order

end

SELFAQ.reverseBagSlot = function( id )

    local info = SELFAQ.itemInBags[id]

    if info == nil then
        return -1
    end

    if type(info) == "table" then
        return info[1], info[2]
    end

    local bag = math.floor(info/100)
    local slot = info%100

    return bag, slot

end

SELFAQ.otherSlot = function(slot_id)
    
    local other = 0

    if slot_id == 11 or slot_id == 12 then
        other = 23 - slot_id
    elseif slot_id == 13 or slot_id == 14 then
        other = 27 -slot_id
    elseif slot_id == 16 or slot_id == 17 then
        other = 33 -slot_id
    end

    return other
end

SELFAQ.loopSlots = function( func )
    if not SELFAQ.slots then
        return
    end
    for k,v in pairs(SELFAQ.slots) do
        func(v)
    end
end

-- 调试函数
SELFAQ.debug = function(t)
    if not SELFAQ.enableDebug then
        return
    end

    if type(t) == "table" then
        for k,v in pairs(t) do
            
            if type(v) == "table" then
                print("@DEBUG: ",k)
                SELFAQ.debug(v)
            else
                print("@KV: ",k.." =>"..tostring(v))
            end
        end
    else
        print("@DEBUG: ",t)
    end
end

SELFAQ.chatInfo = function(s)

    if not AQSV or AQSV.hideChatInfo then
        return
    end

    print(L["prefix"]..s)
end

SELFAQ.initSV = function( v, init )
    if v == nil then

        if type(init) == "table" then
            local t = SELFAQ.clone(init)
            return t
        end

        v = init
    end
    return v
end

SELFAQ.GetItemLink = function( id )

    local id, order = SELFAQ.reverseId(id)

    if id == 0 then
        return L["[Empty]"]
    end
    local _, link = GetItemInfo(id)

    if link == nil then
        return ""
    end

    if order >0 then
        link = link.."#"..order
    end

    return link
end

SELFAQ.GetItemEquipLoc = function( id )
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(id)
    return itemEquipLoc
end

SELFAQ.GetItemSlot = function( id )
    local itemEquipLoc = SELFAQ.GetItemEquipLoc(id)
    if not itemEquipLoc then return nil end

    local slot = nil

    if itemEquipLoc == "INVTYPE_TRINKET" then
        slot = 13
    elseif itemEquipLoc == "INVTYPE_CHEST" or itemEquipLoc == "INVTYPE_ROBE" then
        slot = 5
    elseif itemEquipLoc == "INVTYPE_HEAD" then
        slot = 1
    elseif itemEquipLoc == "INVTYPE_NECK" then
        slot = 2
    elseif itemEquipLoc == "INVTYPE_SHOULDER" then
        slot = 3
    elseif itemEquipLoc == "INVTYPE_WAIST" then
        slot = 6
    elseif itemEquipLoc == "INVTYPE_LEGS" then
        slot = 7
    elseif itemEquipLoc == "INVTYPE_FEET" then
        slot = 8
    elseif itemEquipLoc == "INVTYPE_WRIST" then
        slot = 9
    elseif itemEquipLoc == "INVTYPE_HAND" then
        slot = 10
    elseif itemEquipLoc == "INVTYPE_FINGER" then
        slot = 11
    elseif itemEquipLoc == "INVTYPE_CLOAK" then
        slot = 15
    elseif itemEquipLoc == "INVTYPE_WEAPON" then
        slot = 16
    elseif itemEquipLoc == "INVTYPE_SHIELD" or itemEquipLoc == "INVTYPE_WEAPONOFFHAND" or itemEquipLoc == "INVTYPE_HOLDABLE" then
        slot = 17
    elseif itemEquipLoc == "INVTYPE_2HWEAPON" or itemEquipLoc == "INVTYPE_WEAPONMAINHAND" then
        slot = 16
    elseif itemEquipLoc == "INVTYPE_RANGED" or itemEquipLoc == "INVTYPE_THROWN" or itemEquipLoc == "INVTYPE_RANGEDRIGHT" or itemEquipLoc == "INVTYPE_RELIC" then
        slot = 18
    end

    return slot
end

SELFAQ.GetItemTexture = function( id )
    id = SELFAQ.reverseId(id)

    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(id)
    return itemTexture
end

SELFAQ.equipByID = function(item_id, slot_id, popup)

    if not SELFAQ.playerCanEquip() then
        return
    end

    if item_id <= 0 then
        return
    end

    local bag, slot = SELFAQ.reverseBagSlot(item_id)

    if bag >= 0 then

        if CursorHasItem() then
            return false
        end

        ClearCursor()
        PickupContainerItem(bag,slot)

        if CursorHasItem() then
            EquipCursorItem(slot_id)
        end
    else
        EquipItemByName(item_id, slot_id)
    end

end

SELFAQ.popupInfo = function(text)
    -- 弹出提示已移除
end

-- 判断玩家是否可以换装
SELFAQ.playerCanEquip = function()
    if UnitAffectingCombat("player") then
        return false
    end

    if UnitIsDeadOrGhost("player") then
        return false
    end

    if UnitOnTaxi("player") then
        return false
    end

    return true
end
