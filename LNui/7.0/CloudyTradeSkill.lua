local itemDisplay = 30
local numTabs = 0
local function InitDB()
	itemDisplay = U1DB and U1DB.CloudyTradeSkillItemDisplay or itemDisplay
end

--- Create Frame ---
local f = CreateFrame('Frame', 'CloudyTradeSkill')
f:RegisterEvent('TRADE_SKILL_LIST_UPDATE')
f:RegisterEvent('PLAYER_LOGIN')

	local function updateSize()
		if not TradeSkillFrame then return end
		TradeSkillFrame:SetHeight(itemDisplay * 16 + 96) --496
		TradeSkillFrame.RecipeInset:SetHeight(itemDisplay * 16 + 10) --410
		TradeSkillFrame.DetailsInset:SetHeight(itemDisplay * 16 - 10) --390
		TradeSkillFrame.DetailsFrame:SetHeight(itemDisplay * 16 - 15) --385
		TradeSkillFrame.DetailsFrame.Background:SetHeight(itemDisplay * 16 - 17) --383

		if TradeSkillFrame.RecipeList and TradeSkillFrame.RecipeList.FilterBar and TradeSkillFrame.RecipeList.FilterBar:IsVisible() then
			TradeSkillFrame.RecipeList:SetHeight(itemDisplay * 16 - 11) --389
		else
			TradeSkillFrame.RecipeList:SetHeight(itemDisplay * 16 + 5) --405
		end
	end

	--- Mouse Click Events ---
	local offsetX, offsetY
	local function resizeBar_OnMouseDown(self, button)
		if (button == 'LeftButton') and not InCombatLockdown() and TradeSkillFrame then
			offsetX = TradeSkillFrame:GetLeft()
			offsetY = TradeSkillFrame:GetTop()

			TradeSkillFrame:SetResizable(true)
			TradeSkillFrame:SetMinResize(670, offsetY/2 + 100)
			TradeSkillFrame:SetMaxResize(670, offsetY - 50)
			TradeSkillFrame:StartSizing('BOTTOM')
		end
	end
	local function resizeBar_OnMouseUp(self, button)
		if (button == 'LeftButton') and not InCombatLockdown() and TradeSkillFrame then
			TradeSkillFrame:StopMovingOrSizing()
			TradeSkillFrame:SetResizable(false)
			TradeSkillFrame:ClearAllPoints()
			TradeSkillFrame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', offsetX, offsetY)

			local item = (TradeSkillFrame:GetHeight() - 96) / 16
			itemDisplay = floor(item, 0.5)
            if U1DB then
                U1DB.CloudyTradeSkillItemDisplay = itemDisplay
            end
			updateSize()
		end
	end

	--- Change Mouse Cursor ---
	local function resizeBar_OnEnter()
		if not InCombatLockdown() then
			SetCursor('CAST_CURSOR')
		end
	end
	local function resizeBar_OnLeave()
		if not InCombatLockdown() then
			ResetCursor()
		end
    end

CoreDependCall("Blizzard_TradeSkillUI", function()
--- Refresh Recipe List ---
    -- 12.1 优化：严格限定只处理 TradeSkillFrame.RecipeList，避免影响其他 HybridScrollFrame
    hooksecurefunc('HybridScrollFrame_Update', function(self, ...)
        if TradeSkillFrame and self == TradeSkillFrame.RecipeList then
            if self.FilterBar and self.FilterBar:IsVisible() then
                self:SetHeight(itemDisplay * 16 - 11) --389
            else
                self:SetHeight(itemDisplay * 16 + 5) --405
            end
        end
    end)

    --- Create Resize Bar ---
    if TradeSkillFrame then
        local resizeBar = CreateFrame('Button', nil, TradeSkillFrame)
        TradeSkillFrame._resizeBar = resizeBar
        resizeBar:SetPoint("BOTTOMLEFT", TradeSkillFrame)
        resizeBar:SetPoint("BOTTOMRIGHT", TradeSkillFrame)
        resizeBar:SetHeight(16)
        --resizeBar:SetAllPoints(TradeSkillFrameBottomBorder) --broken in 8.1
        resizeBar:SetScript('OnMouseDown', resizeBar_OnMouseDown)
        resizeBar:SetScript('OnMouseUp', resizeBar_OnMouseUp)
        resizeBar:SetScript('OnEnter', resizeBar_OnEnter)
        resizeBar:SetScript('OnLeave', resizeBar_OnLeave)

        updateSize()

        --- Fix SearchBox ---
        hooksecurefunc('ChatEdit_InsertLink', function(link)
            if link and TradeSkillFrame and TradeSkillFrame:IsShown() and TradeSkillFrame.SearchBox then
                local text = strmatch(link, '|h%[(.+)%]|h|r')
                if text then
                    text = strmatch(text, ':%s(.+)') or text
                    TradeSkillFrame.SearchBox:SetText(text:lower())
                end
            end
        end)
        TradeSkillFrame.SearchBox:SetWidth(205)

        --- Fix RecipeLink ---
        if C_TradeSkillUI and C_TradeSkillUI.GetRecipeLink then
            local getRecipe = C_TradeSkillUI.GetRecipeLink
            C_TradeSkillUI.GetRecipeLink = function(link)
                if link and (link ~= '') then
                    return getRecipe(link)
                end
            end
        end
    end
end)

--- Handle Events ---
f:SetScript('OnEvent', function(self, event, ...)
	if (event == 'PLAYER_LOGIN') then
		InitDB()
		if TradeSkillFrame then updateSize() end
	elseif (event == 'TRADE_SKILL_LIST_UPDATE') then
		if TradeSkillFrame and TradeSkillFrame.RecipeList then
			if TradeSkillFrame.RecipeList.buttons and #TradeSkillFrame.RecipeList.buttons < (itemDisplay + 2) then
				HybridScrollFrame_CreateButtons(TradeSkillFrame.RecipeList, 'TradeSkillRowButtonTemplate', 0, 0)
			end
		end
	end
end)