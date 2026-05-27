local _, SELFAQ = ...

local debug = SELFAQ.debug
local clone = SELFAQ.clone
local L = SELFAQ.L
local player = SELFAQ.player
local initSV = SELFAQ.initSV
local GetItemTexture = SELFAQ.GetItemTexture
local GetItemEquipLoc = SELFAQ.GetItemEquipLoc
local loopSlots = SELFAQ.loopSlots
local GetItemLink = SELFAQ.GetItemLink
local chatInfo = SELFAQ.chatInfo
local popupInfo = SELFAQ.popupInfo


-- 初始化插件
function SELFAQ.addonInit()

        SELFAQ.updateAllItems( )

        SELFAQ.settingInit()

end

-- 扫描背包，找出所有可装备到对应槽位的物品
function SELFAQ.scanBagItems()

    SELFAQ.items = {}
    SELFAQ.itemInBags = {}

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local itemID = info.itemID
                local slotID = SELFAQ.GetItemSlot(itemID)

                if slotID and slotID > 0 then
                    -- 检查该槽位是否在我们关注的槽位列表中
                    for _, v in pairs(SELFAQ.slots) do
                        if v == slotID or (SELFAQ.isSharedSlot(slotID, v)) then
                            if not SELFAQ.items[v] then
                                SELFAQ.items[v] = {}
                            end
                            if not tContains(SELFAQ.items[v], itemID) then
                                table.insert(SELFAQ.items[v], itemID)
                            end
                            -- 记录物品在背包中的位置
                            SELFAQ.itemInBags[itemID] = bag * 100 + slot
                        end
                    end
                end
            end
        end
    end
end

-- 判断是否是共享槽位（戒指、饰品、武器等可以装备到两个槽位的）
function SELFAQ.isSharedSlot(itemSlot, targetSlot)
    -- 戒指: 11, 12
    if (itemSlot == 11 or itemSlot == 12) and (targetSlot == 11 or targetSlot == 12) then
        return true
    end
    -- 饰品: 13, 14
    if (itemSlot == 13 or itemSlot == 14) and (targetSlot == 13 or targetSlot == 14) then
        return true
    end
    -- 单手武器可以装备到主手和副手
    if (itemSlot == 16) and (targetSlot == 16 or targetSlot == 17) then
        return true
    end
    return false
end

function SELFAQ.updateAllItems()

    SELFAQ.scanBagItems()

    for k, v in pairs(SELFAQ.slots) do
        SELFAQ.updateItemButton(v)
    end

end
