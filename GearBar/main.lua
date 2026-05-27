local _, SELFAQ = ...

local debug = SELFAQ.debug
local clone = SELFAQ.clone
local diff = SELFAQ.diff
local L = SELFAQ.L
local initSV = SELFAQ.initSV
local loopSlots = SELFAQ.loopSlots
local chatInfo = SELFAQ.chatInfo


-- 注入按键设置页面
for k,v in pairs(SELFAQ.gearSlots) do
    _G["BINDING_NAME_GEARBAR_BUTTON"..v] = SELFAQ.slotToName[v]
end

_G.BINDING_HEADER_GEARBAR_INVENTORYBAR_BUTTON = L["Equipment Bar Button"]

-- 注册事件
SELFAQ.main = CreateFrame("Frame")


-- 斜杠命令
function SELFAQ.mainInit()

    SLASH_GEARBARCMD1 = "/gearbar";
    function SlashCmdList.GEARBARCMD(msg)
        InterfaceOptionsFrame_OpenToCategory(SELFAQ.top);
        InterfaceOptionsFrame_OpenToCategory(SELFAQ.top);
    end

end

-- 注册事件
SELFAQ.main:RegisterEvent("ADDON_LOADED")
SELFAQ.main:RegisterEvent("UNIT_INVENTORY_CHANGED")
SELFAQ.main:RegisterEvent("UPDATE_BINDINGS")
SELFAQ.main:RegisterEvent("BAG_UPDATE")

SELFAQ.main:SetScript("OnEvent", function( self, event, arg1 )

    if event == "ADDON_LOADED" and arg1 == "GearBar" then

        AQSV = initSV(AQSV, {})
        AQSV.x = initSV(AQSV.x, 600)--lnui
        AQSV.y = initSV(AQSV.y, -200)--lnui
        AQSV.point = initSV(AQSV.point, "CENTER")
        AQSV.locked = initSV(AQSV.locked, false)
        AQSV.enableItemBar = initSV(AQSV.enableItemBar, true)
        AQSV.enableItemBarSlot = initSV(AQSV.enableItemBarSlot, {[13]=true, [14]=true})

        AQSV.barZoom = initSV(AQSV.barZoom, 0.9)--lnui
        AQSV.buttonSpacingNew = initSV(AQSV.buttonSpacingNew, 3)
        AQSV.hideBackdrop = initSV(AQSV.hideBackdrop, false)
        AQSV.hotkeyFontSize = initSV(AQSV.hotkeyFontSize, 8)
        AQSV.fontPath = initSV(AQSV.fontPath, [[Fonts\FRIZQT__.TTF]])

        AQSV.popupX = initSV(AQSV.popupX, 0)
        AQSV.popupY = initSV(AQSV.popupY, 320)

        if AQSV.slotStatus == nil then
            AQSV.slotStatus = {}
            for k,v in pairs(SELFAQ.slotToName) do
                AQSV.slotStatus[k] = {
                    ["backup"] = 0,
                    ["locked"] = false,
                    ["lockedCD"] = false,
                    ["lockedTime"] = 0,
                }
            end
        end

        for k,v in pairs(SELFAQ.slotToName) do
            AQSV.slotStatus[k] = initSV(AQSV.slotStatus[k], {})
            AQSV.slotStatus[k].backup = initSV(AQSV.slotStatus[k].backup, 0)
            AQSV.slotStatus[k].locked = initSV(AQSV.slotStatus[k].locked, false)
            AQSV.slotStatus[k].lockedCD = initSV(AQSV.slotStatus[k].lockedCD, false)
            AQSV.slotStatus[k].lockedTime = initSV(AQSV.slotStatus[k].lockedTime, 0)
        end

        SELFAQ.addonInit()

        SELFAQ.createItemBar()

        SELFAQ.mainInit()

        -- chatInfo(L["GearBar "]..SELFAQ.version.." "..L["Loaded"])--lnui

    end

    if event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
        if not AQSV then return end
        for k,v in pairs(SELFAQ.slots) do
            SELFAQ.updateItemButton( v )
        end
    end

    if event == "UPDATE_BINDINGS" then
        if not AQSV then return end
        SELFAQ.bindingSlot()
    end

    if event == "BAG_UPDATE" then
        if not AQSV then return end
        SELFAQ.updateAllItems( )
    end

end)
