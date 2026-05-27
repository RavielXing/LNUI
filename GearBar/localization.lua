local _, SELFAQ = ...

local color = SELFAQ.color

SELFAQ.color =  function( rgb, text )
    return "|cFF"..rgb..text.."|r"
end

local color = SELFAQ.color

local L = setmetatable({}, {
    __index = function(table, key)
        if key then
            table[key] = tostring(key)
        end
        return tostring(key)
    end,
})

SELFAQ.L = L

local locale = GetLocale()

L["prefix"] = "|cFFBF6B31<|r|cFFFFFF00GearBar|r|cFFBF6B31>|r"

-- 英文 (默认/回退)
if locale == 'enUS' or locale == 'enGB' then

	L["Loaded"] = "Loaded"

	L[" Lock frame"] = " Lock frame"
	L[" Settings"] = " Settings"
	L[" Close"] = " Close"
	L["Enable Equipment Bar"] = "Enable Equipment Bar"

	L["Button Zoom"] = "Button Zoom"
	L["#Effective after ENTER"] = "#Effective after ENTER"
	L["[Empty]"] = "[Empty|No swap]"
	L["Equipment Bar Button"] = "Equipment Bar Button"

	L["Head"] = "Head"
	L["Neck"] = "Neck"
	L["Shoulder"] = "Shoulder"
	L["Chest"] = "Chest"
	L["Waist"] = "Waist"
	L["Legs"] = "Legs"
	L["Feet"] = "Feet"
	L["Wrist"] = "Wrist"
	L["Hands"] = "Hands"
	L["Finger "] = "Finger "
	L["Trinket "] = "Trinket "
	L["Back"] = "Back"
	L["MainHand"] = "MainHand"
	L["OffHand"] = "OffHand"
	L["Ranged"] = "Ranged"

	L["Lock Equipment Bar"] = "Lock Equipment Bar"
	L["Hide Equipment Bar Background"] = "Hide Equipment Bar Background"
	L["Button Spacing"] = "Button Spacing"
	L["#Effective after Reload UI"] = "#Effective after Reload UI"
	L["Reload UI"] = "Reload UI"
	L["Hotkey Font Size"] = "Hotkey Font Size"
	L["Font Path"] = "Font Path"
	L["GearBar "] = "GearBar "

end

-- 中文
if locale == 'zhCN' then

	L["Loaded"] = "加载完毕"

	L[" Lock frame"] = " 锁定框架"
	L[" Settings"] = " 打开设置"
	L[" Close"] = " 关闭菜单"
	L["Enable Equipment Bar"] = "启用装备栏"

	L["Button Zoom"] = "按钮缩放"
	L["#Effective after ENTER"] = "#回车后生效"
	L["[Empty]"] = "[空|不更换]"
	L["Equipment Bar Button"] = "装备栏按钮"

	L["Head"] = "头部"
	L["Neck"] = "颈部"
	L["Shoulder"] = "肩部"
	L["Chest"] = "胸部"
	L["Waist"] = "腰部"
	L["Legs"] = "腿部"
	L["Feet"] = "脚"
	L["Wrist"] = "手腕"
	L["Hands"] = "手"
	L["Finger "] = "手指"
	L["Trinket "] = "饰品"
	L["Back"] = "背部"
	L["MainHand"] = "主手"
	L["OffHand"] = "副手"
	L["Ranged"] = "远程"

	L["Lock Equipment Bar"] = "锁定装备栏"
	L["Hide Equipment Bar Background"] = "隐藏装备栏背景"
	L["Button Spacing"] = "按钮间距"
	L["#Effective after Reload UI"] = "#重载UI后生效"
	L["Reload UI"] = "重新加载UI"
	L["Hotkey Font Size"] = "快捷键字体大小"
	L["Font Path"] = "字体路径"
	L["GearBar "] = "GearBar "

end

-- 繁体
if locale == 'zhTW' then

	L["Loaded"] = "加載完畢"

	L[" Lock frame"] = " 鎖定框架"
	L[" Settings"] = " 打開設置"
	L[" Close"] = " 關閉菜單"
	L["Enable Equipment Bar"] = "啟用裝備欄"

	L["Button Zoom"] = "按鈕縮放"
	L["#Effective after ENTER"] = "#回車後生效"
	L["[Empty]"] = "[空|不更換]"
	L["Equipment Bar Button"] = "裝備欄按鈕"

	L["Head"] = "頭部"
	L["Neck"] = "頸部"
	L["Shoulder"] = "肩部"
	L["Chest"] = "胸部"
	L["Waist"] = "腰部"
	L["Legs"] = "腿部"
	L["Feet"] = "腳"
	L["Wrist"] = "手腕"
	L["Hands"] = "手"
	L["Finger "] = "手指"
	L["Trinket "] = "飾品"
	L["Back"] = "背部"
	L["MainHand"] = "主手"
	L["OffHand"] = "副手"
	L["Ranged"] = "遠程"

	L["Lock Equipment Bar"] = "鎖定裝備欄"
	L["Hide Equipment Bar Background"] = "隱藏裝備欄背景"
	L["Button Spacing"] = "按鈕間距"
	L["#Effective after Reload UI"] = "#重載UI後生效"
	L["Reload UI"] = "重新加載UI"
	L["Hotkey Font Size"] = "快捷鍵字體大小"
	L["Font Path"] = "字體路徑"
	L["GearBar "] = "GearBar "

end
