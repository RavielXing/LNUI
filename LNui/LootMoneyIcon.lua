--------------------------
-- 錢幣圖標和修理裝備提示
--------------------------
-- 预编译 pattern（模块级常量）：CHAT_MSG_SYSTEM 消息过滤会被高频调用，
-- 避免每次消息都重复执行 gsub 提取 pattern
local GOLD_PATTERN = gsub(GOLD_AMOUNT, "%%d*%s*", "")
local SILVER_PATTERN = gsub(SILVER_AMOUNT, "%%d*%s*", "")
local COPPER_PATTERN = gsub(COPPER_AMOUNT, "%%d*%s*", "")

local function AddMoneyIcon(self, event, message)
	local gm = strmatch(message, "%d+%s*"..GOLD_PATTERN)
	local sm = strmatch(message, "%d+%s*"..SILVER_PATTERN)
	local cm = strmatch(message, "%d+%s*"..COPPER_PATTERN)
	if gm or sm or cm then
		self:AddMessage(format('|cFFFFFF00%s|r', gsub(gsub(gsub(message, GOLD_PATTERN, "\124TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:2:0\124t"), SILVER_PATTERN, "\124TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d:2:0\124t"), COPPER_PATTERN, "\124TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d:2:0\124t")))
		return true
	end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", AddMoneyIcon)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", AddMoneyIcon)


--================================修理裝備提示================================--
local frame = CreateFrame("Frame", nil, UIParent) 
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 400) -- 調整frame在屏幕的位置 
frame:SetWidth(1200)      -- 足夠大點，不然點擊不到 
frame:SetHeight(40) 
frame:Hide() 
frame:SetScale(1) 
frame:EnableMouse(true) -- 確保鼠標按鍵有效 

local FrameText = frame:CreateFontString(nil,"ARTWORK"); 
FrameText:SetFontObject(GameFontNormal); 
FrameText:SetFont(SystemFont_Outline_Small:GetFont(), 40,"outline") 
FrameText:SetTextColor(0.8,0,0,1) -- change this to change color 
FrameText:SetPoint("CENTER")     -- text正常設置到frame自身 
FrameText:SetText(LOCALE_zhCN and "装备都红了，还不滚去修！" or "裝備都紅了，還不滾去修！")  -- 沒其他用途，就只需要設置一次 

local getDurability = (C_Item and C_Item.GetInventoryItemDurability) or GetInventoryItemDurability
frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY") 
frame:RegisterEvent("PLAYER_ENTERING_WORLD") 

frame:SetScript("OnEvent", function(self) 
    if not getDurability then return end
    for id=20,1,-1  do 
        local cur, max = getDurability(id) 
        if cur and max and cur/max <= 0.1 then --這裏修改需要提醒的百分比 
            frame:Show() 
            return -- 只要有一件，不做多余檢查，否則你的代碼只有第一件裝備需要修理時才會顯示 
        end 
    end 
    frame:Hide() 
end) 

-- 處理右鍵點擊 
frame:SetScript("OnMouseUp", function(self, btn) 
    if btn == "RightButton" then 
        frame:Hide() 
    end 
end)
