--## Version: 0.1.2
--## Notes: Adds saved instances info to EncounterJournal (TWW 12.1 Compatible)
--## Author: PeckZeg (Modified for 12.1 API)

local savedInstancesCache = nil
local CACHE_EXPIRY = 2
local cacheTime = 0

local function GetSavedInstances()
    local now = GetTime()
    if savedInstancesCache and (now - cacheTime) < CACHE_EXPIRY then
        return savedInstancesCache
    end
    
    local db = { dungeons = {}, raids = {} }
    for i = 1, GetNumSavedInstances() do
        local name, id, _, difficulty, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
        if name == (LOCALE_zhCN and "围攻伯拉勒斯" or "圍攻伯拉勒斯") then numEncounters = 4 end
        local instances = isRaid and db.raids or db.dungeons

        instances[name] = instances[name] or {}
        if locked or extended then
            table.insert(instances[name], {
                index = i, name = name, difficulty = difficulty,
                locked = locked, extended = extended, isRaid = isRaid,
                maxPlayers = maxPlayers, difficultyName = difficultyName,
                numEncounters = numEncounters, encounterProgress = encounterProgress,
            })
            table.sort(instances[name], function(a, b) return a.difficulty < b.difficulty end)
        end
    end
    savedInstancesCache = db
    cacheTime = now
    return db
end

local function GetEncounterJournalInstanceTabs()
    if EncounterJournal ~= nil then
        return EncounterJournal.dungeonsTab, EncounterJournal.raidsTab
    end
    return nil, nil
end

local function HandleEncounterJournalScrollInstances(func)
    if EncounterJournal and EncounterJournal.instanceSelect and EncounterJournal.instanceSelect.ScrollBox then
        local view = EncounterJournal.instanceSelect.ScrollBox.view
        if view and view.frames then
            for index, instanceButton in pairs(view.frames) do
                if type(instanceButton) == "table" and instanceButton.instanceID then
                    func(instanceButton)
                end
            end
        end
    end
end

local function ResetEncounterJournalScrollInstancesInfo()
    HandleEncounterJournalScrollInstances(function(instanceButton)
        if instanceButton.instanceInfoDifficulty == nil then
            instanceButton.instanceInfoDifficulty = instanceButton:CreateFontString(
                nil,
                "OVERLAY",
                "QuestTitleFontBlackShadow"
            )
        end

        if instanceButton.instanceInfoEncounterProgress == nil then
            instanceButton.instanceInfoEncounterProgress = instanceButton:CreateFontString(
                nil,
                "OVERLAY",
                "QuestTitleFontBlackShadow"
            )
        end

        local difficultyText = instanceButton.instanceInfoDifficulty
        local encounterProgressText = instanceButton.instanceInfoEncounterProgress
        local font = difficultyText:GetFont()

        difficultyText:SetPoint("BOTTOMLEFT", 9, 7)
        difficultyText:SetJustifyH("LEFT")
        difficultyText:SetFont(font, 12)
        difficultyText:SetText("")
        difficultyText:Hide()

        encounterProgressText:SetPoint("BOTTOMRIGHT", -7, 7)
        encounterProgressText:SetJustifyH("RIGHT")
        encounterProgressText:SetFont(font, 12)
        encounterProgressText:Hide()
        encounterProgressText:SetText("")
    end)
end

local function RenderInstanceInfo(instanceButton, savedInstance)
    local diffBtn = instanceButton.instanceInfoDifficulty
    local progBtn = instanceButton.instanceInfoEncounterProgress
    if not diffBtn or not progBtn then return end

    local diffLines, progLines = {}, {}
    for _, instance in ipairs(savedInstance) do
        table.insert(diffLines, instance.difficultyName)
        table.insert(progLines, string.format("%s/%s", instance.encounterProgress, instance.numEncounters))
    end

    diffBtn:SetText(table.concat(diffLines, "\n"))
    diffBtn:SetWidth(diffBtn:GetStringWidth() * 1.25)
    diffBtn:Show()

    progBtn:SetText(table.concat(progLines, "\n"))
    progBtn:SetWidth(progBtn:GetStringWidth() * 1.25)
    progBtn:Show()
end

local function RenderEncounterJournalInstances()
    local savedDB = GetSavedInstances()
    local dungeonsTab, raidsTab = GetEncounterJournalInstanceTabs()
    if EncounterJournal and EncounterJournal.selectedTab == 5 then return end
    local savedInstances = savedDB[(raidsTab ~= nil and not raidsTab:IsEnabled()) and "raids" or "dungeons"]

    HandleEncounterJournalScrollInstances(function(instanceButton)
        local instanceName = EJ_GetInstanceInfo(instanceButton.instanceID)
        local savedInstance = instanceName and savedInstances[instanceName]
        if savedInstance then
            RenderInstanceInfo(instanceButton, savedInstance)
        end
    end)
end

local function EncounterJournalInstanceTab_OnClick()
    for _, tab in ipairs({ "dungeonsTab", "raidsTab" }) do
        if EncounterJournal and EncounterJournal[tab] and EncounterJournal[tab].HookScript then
            EncounterJournal[tab]:HookScript("OnClick", function(self, button, down)
                savedInstancesCache = nil
                ResetEncounterJournalScrollInstancesInfo()
                RequestRaidInfo()
            end)
        end
    end
end

function EncounterJournalPlus_InstanceInfo_OnLoad(self)
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("UPDATE_INSTANCE_INFO")
end

function EncounterJournalPlus_InstanceInfo_OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_EncounterJournal" then
        -- 12.1 Fix: EJ_ContentTab_Select 在 TWW 中已移除，先检查再 hook，避免报错
        if type(EJ_ContentTab_Select) == "function" then
            hooksecurefunc("EJ_ContentTab_Select", function(id)
                if id ~= 1 and id ~= 3 then
                    savedInstancesCache = nil
                    ResetEncounterJournalScrollInstancesInfo()
                    RequestRaidInfo()
                end
            end)
        elseif EncounterJournal and EncounterJournal.SetTab then
            -- 备选：12.1 中 EncounterJournal 使用 SetTab 方法
            hooksecurefunc(EncounterJournal, "SetTab", function(self, id)
                if id ~= 1 and id ~= 3 then
                    savedInstancesCache = nil
                    ResetEncounterJournalScrollInstancesInfo()
                    RequestRaidInfo()
                end
            end)
        end
        
        -- 12.1 Fix: 同样安全处理 EJ_SelectTier
        if type(EJ_SelectTier) == "function" then
            hooksecurefunc("EJ_SelectTier", function()
                savedInstancesCache = nil
                ResetEncounterJournalScrollInstancesInfo()
                RequestRaidInfo()
            end)
        end
        
        EncounterJournalInstanceTab_OnClick()
    elseif event == "UPDATE_INSTANCE_INFO" then
        RenderEncounterJournalInstances()
    end
end

local frame = CreateFrame("Frame")
EncounterJournalPlus_InstanceInfo_OnLoad(frame)
frame:SetScript("OnEvent", EncounterJournalPlus_InstanceInfo_OnEvent)