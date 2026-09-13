--[重載命令] 
SlashCmdList["RELOADUI"] = function() ReloadUI() end 
SLASH_RELOADUI1 = "/rl"
SLASH_RELOADUI2 = "/aa"

--刪除自動輸入DELETE---
hooksecurefunc(StaticPopupDialogs["DELETE_GOOD_ITEM"],"OnShow",function(s) s:GetEditBox():SetText(DELETE_ITEM_CONFIRM_STRING) end)
hooksecurefunc(StaticPopupDialogs["DELETE_GOOD_QUEST_ITEM"],"OnShow",function(s) s:GetEditBox():SetText(DELETE_ITEM_CONFIRM_STRING) end)

--[網格界面校正] 
SLASH_EA1 = "/ab" 
local f
SlashCmdList["EA"] = function()
	if f then
		f:Hide()
		f = nil		
	else
		f = CreateFrame('Frame', nil, UIParent) 
		f:SetAllPoints(UIParent)
		local w = GetScreenWidth() / 64
		local h = GetScreenHeight() / 36
		for i = 0, 64 do
			local t = f:CreateTexture(nil, 'BACKGROUND')
			if i == 32 then
				t:SetColorTexture(1, 0, 0, 0.5)
			else
				t:SetColorTexture(0, 0, 0, 0.5)
			end
			t:SetPoint('TOPLEFT', f, 'TOPLEFT', i * w - 1, 0)
			t:SetPoint('BOTTOMRIGHT', f, 'BOTTOMLEFT', i * w + 1, 0)
		end
		for i = 0, 36 do
			local t = f:CreateTexture(nil, 'BACKGROUND')
			if i == 18 then
				t:SetColorTexture(1, 0, 0, 0.5)
			else
				t:SetColorTexture(0, 0, 0, 0.5)
			end
			t:SetPoint('TOPLEFT', f, 'TOPLEFT', 0, -i * h + 1)
			t:SetPoint('BOTTOMRIGHT', f, 'TOPRIGHT', 0, -i * h - 1)
		end	
	end
end

--I鍵頁面添加按鈕查看9.0低保
local clear = CreateFrame("Button", "AddUISaveButton", PVEFrame.NineSlice, "UIPanelButtonTemplate")
clear:SetText(LOCALE_zhCN and "宏伟宝库奖励" or "宏偉寶庫獎勵")
clear:SetWidth(110)
clear:SetHeight(22)
clear:SetPoint("TOPLEFT", 57, 0)
clear:SetScript("OnClick", function()
	if (WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown()) then
	HideUIPanel(WeeklyRewardsFrame);
	else
	LoadAddOn("Blizzard_WeeklyRewards"); WeeklyRewardsFrame:Show()
	end
end)

--移動盟約圖標，10.0是馭龍術圖標了
-- ExpansionLandingPageMinimapButton:ClearAllPoints();
-- ExpansionLandingPageMinimapButton:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -10, 25);
-- ExpansionLandingPageMinimapButton:SetSize(36,36)
