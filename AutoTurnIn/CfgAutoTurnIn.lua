U1RegisterAddon("AutoTurnIn", {
	title = "自动交接任务",
    defaultEnable = 1,
    tags = { TAG_MAPQUEST, },
	icon = [[Interface\AddOns\AutoTurnIn\icon]],
	desc = "说明``自动交接任务，并在任务奖励处直接显示物品售价(此功能来自Abin的QuestPrice)",
	nopic = 1,

	runBeforeLoad = function(info, name)
		local AutoTurnIn = AutoTurnIn;
		if AutoTurnIn then
			local _CinematickHooks = AutoTurnIn.CinematickHooks;
			function AutoTurnIn:CinematickHooks(...)
				local _Print = self.Print;
				self.Print = function() end
				local ret = { _CinematickHooks(self, ...) };
				self.Print = _Print;
				return unpack(ret);
			end
			local _DEPRECATED_CinematickHooks = AutoTurnIn.DEPRECATED_CinematickHooks;
			function AutoTurnIn:DEPRECATED_CinematickHooks(...)
				local _Print = self.Print;
				self.Print = function() end
				local ret = { _DEPRECATED_CinematickHooks(self, ...) };
				self.Print = _Print;
				return unpack(ret);
			end
		end
	end,

	toggle = function(name, info, enable, justload)
		if ( justload ) then
			AutoTurnInTrackerQuickSwitch:SetChecked(LibStub("AceAddon-3.0"):GetAddon("AutoTurnIn").db.profile.enabled)
			hooksecurefunc(AutoTurnIn, "SetEnabled", function(self, enabled)
				AutoTurnInTrackerQuickSwitch:SetChecked(enabled);
			end)
		end
	end,
    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("AutoTurnIn"))
        end
    }
});

local WatchFrame = WatchFrame or QuestWatchFrame or ObjectiveTrackerFrame;
if WatchFrame.BlocksFrame == nil then
	WatchFrame.BlocksFrame = {  };
	local QuestHeader = CreateFrame('FRAME', nil, WatchFrame);
	QuestHeader:SetPoint("TOPLEFT", 0, 12);
	QuestHeader:SetPoint("TOPRIGHT", 0, 12);
	QuestHeader:SetHeight(24);
	WatchFrame.BlocksFrame.QuestHeader = QuestHeader;
end
local QuestHeader = WatchFrame.BlocksFrame.QuestHeader;

local checkbox = CreateFrame("CheckButton", "AutoTurnInTrackerQuickSwitch", WatchFrame, "UICheckButtonTemplate");
checkbox:SetChecked(false)
checkbox:SetParent(QuestHeader)
checkbox:RegisterForClicks("AnyUp")
checkbox:SetWidth(22);
checkbox:SetHeight(22);
if checkbox.text == nil then
	checkbox.text = checkbox:CreateFontString(nil, "ARTWORK");
	checkbox.text:SetFont(GameFontNormal:GetFont(), 16, "");
	checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0);
end
checkbox.text:SetText("自动交接")
checkbox:SetPoint("BOTTOMRIGHT", QuestHeader, "BOTTOMRIGHT", -160, -15);
CoreDependCall("!KalielsTracker", function()
	checkbox.text:SetText("自")
	checkbox:SetPoint("BOTTOMRIGHT", QuestHeader, "BOTTOMRIGHT", -125, 2)
end)
checkbox:SetScript("OnClick", function(self, button)
	if( not IsAddOnLoaded("AutoTurnIn") ) then U1LoadAddOn("AutoTurnIn") end
	if( not IsAddOnLoaded("AutoTurnIn") ) then U1Message("请安装AutoTurnIn插件") return end
	if(button == "RightButton") then
		local func = CoreIOF_OTC or InterfaceOptionsFrame_OpenToCategory
		func("AutoTurnIn")
		self:SetChecked(not self:GetChecked())
	else
		if( self:GetChecked() ) then
			-- AutoTurnIn:ConsoleComand("on")
			AutoTurnIn:SetEnabled(true)
		else
			-- AutoTurnIn:ConsoleComand("off")
			AutoTurnIn:SetEnabled(false)
		end
	end
end);
CoreUIEnableTooltip(checkbox, "自动交接", "左键：开启/关闭自动交接任务\n右键：设置选项\n\n按住热键(默认SHIFT)点击NPC，则暂时停用或启用自动交接。")
