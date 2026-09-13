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

-- 12.x: C_QuestLog 返回的表字段可能是 secret 值。
-- 任何对 secret 值的比较、字段访问或字符串操作都会污染当前执行链。
-- 这段逻辑通过 hooksecurefunc 挂在 ObjectiveTracker 的 HeaderText:SetText 上，
-- 污染会顺着布局代码一路传到 ScenarioObjectiveTracker:LayoutContents，
-- 最终令 GetAuraDataByIndex 抛出 "Auras cannot be accessed when secret"。
--
-- 修复策略：
--   1) SetText 钩子内只捕获参数，不做任何读取/比较，立即返回；
--   2) 真正的格式化工作用 C_Timer.After(0, ...) 完全移出 ObjectiveTracker 的同步更新链；
--   3) 定时器回调中再做 secret 检查 + pcall 保护，任何失败都退回原文本。
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
		if IsSecret(questLogIndex) or not questLogIndex then
			return nil
		end

		local info = C_QuestLog.GetInfo(questLogIndex)
		if IsSecret(info) or not info then
			return nil
		end
		if IsSecret(info.isHeader) or info.isHeader then
			return nil
		end

		local level = C_QuestLog.GetQuestDifficultyLevel(questID)
		if IsSecret(level) then
			return nil
		end
		if type(level) ~= "number" or level <= 0 then
			level = info.level
		end
		if IsSecret(level) or type(level) ~= "number" or level <= 0 then
			return nil
		end

		if text:find("^%s*%[%d+[^%]]*%]") then
			return nil
		end

		if watched then
			local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
			if IsSecret(tagInfo) then
				return nil
			end
			local tag = ""
			if tagInfo and not IsSecret(tagInfo.tagID) then
				tag = AutoTurnIn.QuestTypesIndex[tagInfo.tagID] or ""
			end

			local recurring = false
			if not IsSecret(info.frequency) then
				recurring = info.frequency == Enum.QuestFrequency.Daily
					or info.frequency == Enum.QuestFrequency.Weekly
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
		if updating then return end

		-- 钩子内只做参数捕获，不读取 text 的内容、不访问 getQuestID()。
		-- 把一切交给下一帧的定时器，从而彻底离开 ObjectiveTracker 的同步更新链。
		local capturedText = text
		C_Timer.After(0, function()
			if updating then return end
			if capturedText == nil then return end
			if IsSecret(capturedText) then return end
			if type(capturedText) ~= "string" or capturedText == "" then return end

			local questID
			local qidOk = pcall(function() questID = getQuestID() end)
			if not qidOk or questID == nil then return end
			if IsSecret(questID) then return end

			local originalText = capturedText
			if questID == previousQuestID and capturedText == previousResult then
				originalText = previousText
			end

			local result
			local fmtOk = pcall(function()
				result = FormatQuestTitle(questID, originalText, watched)
			end)
			if not fmtOk or result == nil then return end
			if IsSecret(result) then return end
			if result == capturedText then return end

			previousQuestID, previousText, previousResult = questID, originalText, result

			updating = true
			pcall(fontString.SetText, fontString, result)
			updating = false
		end)
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
	if ok and block and block.HeaderText then
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
			-- GetBlock 运行在 ObjectiveTracker 更新链中，回调内部只登记按钮，
			-- 具体的 SetText 处理在 HookTitleText 里已经异步化了。
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