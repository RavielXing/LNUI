AutoTurnIn.QuestLevelFormat = "[%d] %s"
AutoTurnIn.WatchFrameLevelFormat = "[%d%s%s] %s"
AutoTurnIn.QuestTypesIndex = {
	[0] = "",          -- Default
	[1] = "g",         -- Group
	[41] = "+",        -- PvP
	[62] = "r",        -- Raid
	[81] = "d",        -- Dungeon
	[83] = "L",        -- Legendary
	[85] = "h",        -- Heroic
	[98] = "s",        -- Scenario
	[102] = "a",       -- Account
}

local hookedText = setmetatable({}, {__mode = "k"})
local hookedPools = setmetatable({}, {__mode = "k"})
local hookedModules = setmetatable({}, {__mode = "k"})
local questLevelEvents

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

-- 12.x: C_QuestLog 返回的表字段（frequency / level 等）可能是 secret 值。
-- 任何对 secret 值的比较或运算都会污染当前执行链，而这段逻辑是通过
-- hooksecurefunc 挂在 ObjectiveTracker 的 HeaderText:SetText 上的，
-- 污染会顺着布局代码一路传到 ScenarioObjectiveTracker:LayoutContents，
-- 最终令 GetAuraDataByIndex 抛出 "Auras cannot be accessed when secret"。
-- 因此整段格式化必须放在 pcall 内，并在访问任何字段前先做 secret 检查；
-- 任一环节失败就退回原文本，让 Blizzard 的布局逻辑保持干净。
local function FormatQuestTitle(questID, text, watched)
	local profile = AutoTurnIn.db and AutoTurnIn.db.profile
	local option = watched and "watchlevel" or "questlevel"
	if not (profile and profile.enabled and profile[option]) then
		return text
	end
	if IsSecret(questID) or type(questID) ~= "number" or questID <= 0 then
		return text
	end

	local ok, result = pcall(function()
		local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
		if IsSecret(questLogIndex) then
			return nil
		end

		local info = questLogIndex and C_QuestLog.GetInfo(questLogIndex)
		if IsSecret(info) or not info or info.isHeader then
			return nil
		end

		local level = C_QuestLog.GetQuestDifficultyLevel(questID)
		if IsSecret(level) then
			return nil
		end
		if not level or level <= 0 then
			level = info.level
		end
		if IsSecret(level) or type(level) ~= "number" or level <= 0 then
			return nil
		end

		-- Respect a level already supplied by another addon, but allow [DNT], etc.
		if text:find("^%s*%[%d+[^%]]*%]") then
			return nil
		end

		if watched then
			local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
			if IsSecret(tagInfo) then
				return nil
			end
			local tag = tagInfo and AutoTurnIn.QuestTypesIndex[tagInfo.tagID] or ""

			local freq = info.frequency
			local recurring = false
			if not IsSecret(freq) then
				recurring = freq == Enum.QuestFrequency.Daily or freq == Enum.QuestFrequency.Weekly
			end

			return AutoTurnIn.WatchFrameLevelFormat:format(level, tag or "", recurring and "*" or "", text)
		end
		return AutoTurnIn.QuestLevelFormat:format(level, text)
	end)

	if ok and result then
		return result
	end
	return text
end

local function HookTitleText(fontString, getQuestID, watched)
	if not fontString or hookedText[fontString] then
		return
	end
	hookedText[fontString] = true
	local updating, previousQuestID, previousText, previousResult
	hooksecurefunc(fontString, "SetText", function(_, text)
		if updating or IsSecret(text) or type(text) ~= "string" or text == "" then
			return
		end
		local questID = getQuestID()
		if IsSecret(questID) then
			return
		end
		local originalText = text
		if questID == previousQuestID and text == previousResult then
			originalText = previousText
		end
		local result = FormatQuestTitle(questID, originalText, watched)
		previousQuestID, previousText, previousResult = questID, originalText, result
		if result ~= text then
			updating = true
			fontString:SetText(result)
			updating = false
		end
	end)
end

local function GetQuestTitlePool()
	local questsFrame = QuestMapFrame and QuestMapFrame.QuestsFrame
	local scrollFrame = QuestScrollFrame or (questsFrame and questsFrame.ScrollFrame)
	return (scrollFrame and scrollFrame.titleFramePool) or (questsFrame and questsFrame.titleFramePool)
end

function AutoTurnIn:ShowQuestLevelInLog()
	local pool = GetQuestTitlePool()
	if not pool then
		return
	end
	for button in pool:EnumerateActive() do
		HookTitleText(button.Text, function()
			return button.questID
		end, false)
	end
end

local function HookTrackerBlock(module, id, template)
	-- 直接调用 Blizzard 的 GetExistingBlock 会继承当前 taint 状态，
	-- 用 pcall 隔离，避免加载阶段的异常污染 tracker 内部状态。
	local ok, block = pcall(module.GetExistingBlock, module, id, template)
	if ok and block then
		HookTitleText(block.HeaderText, function()
			return block.id
		end, true)
	end
end

function AutoTurnIn:ShowQuestLevelInWatchFrame()
	-- Only quest modules: achievement IDs can also match IDs in the quest log.
	local moduleNames = {"QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "WorldQuestObjectiveTracker", "BonusObjectiveTracker"}
	for _, name in ipairs(moduleNames) do
		local module = _G[name]
		if module and module.GetBlock and module.GetExistingBlock and not hookedModules[module] then
			hookedModules[module] = true
			-- GetBlock runs before SetHeader measures the text and lays out objectives.
			hooksecurefunc(module, "GetBlock", HookTrackerBlock)
			if module.EnumerateActiveBlocks then
				pcall(function()
					module:EnumerateActiveBlocks(function(block)
						HookTrackerBlock(module, block.id, block.template)
					end)
				end)
			end
		end
	end
end

function AutoTurnIn:QuestLevelHooks()
	local pool = GetQuestTitlePool()
	if pool and not hookedPools[pool] then
		hookedPools[pool] = true
		-- Attach to new rows before Blizzard sets their titles and measures them.
		hooksecurefunc(pool, "Acquire", function()
			AutoTurnIn:ShowQuestLevelInLog()
		end)
		self:ShowQuestLevelInLog()
	end
	self:ShowQuestLevelInWatchFrame()

	-- These UI addons can load after AutoTurnIn. Keep this separate from the
	-- automation events, which are unregistered when the addon is disabled.
	if not questLevelEvents then
		questLevelEvents = CreateFrame("Frame")
		questLevelEvents:RegisterEvent("ADDON_LOADED")
		questLevelEvents:SetScript("OnEvent", function()
			AutoTurnIn:QuestLevelHooks()
		end)
	end
end