--todo: 团队通报
--战斗关闭
--单人通报，设置频道，设置玩家，选择boss和难度，合计，选择次数,
--人员选择，设置频道，职业-天赋 GS，boss选择
--插件状态提示
--初次打开的信息提示
--todo: 缩放可以横向扩大
--todo: 保持排序
--todo: 有时名单有问题, 定时刷新
local _, TeamStats = ...
TeamStats = LibStub("AceTimer-3.0"):Embed(TeamStats);
local L = TeamStats.L
_G["TeamStats"] = TeamStats

local InspectLess = LibStub("LibInspectLess-1.0")

TeamStats.names = {} --保存当前团队名单, true为当前在队伍里的, false为离队的, nil为没关系的
TeamStats.temp_data = {} --保存临时数据, RL就丢失, player为key

local TABS = TeamStats.TABS
local VBOSSES = TeamStats.VERSION_BOSSES
local CHECK_DELAY = 3 --首次登入游戏时开始检查的延迟, 防止拖慢进游戏的速度
local CHECK_INTERVAL = 1.5 --每次检查之间的间隔时间
local INSPECT_TIMEOUT = 3 --观察天赋的超时时间, 如果一直没有返回会阻断循环
local MAX_KEEP_DAYS = 2
local PLAYER_REALM = GetRealmName()
local UNKNOWN_TARGET = "未知目标"

local function GetPlayerData(name)
    if TeamStats.names[name] ~= nil then
        local player = TeamStats.db.players[name]
        if not player then
            player = {}
            TeamStats.db.players[name] = player
        end
        return player
    end
end

local function SafeString(v)
    if issecretvalue and type(issecretvalue) == "function" and issecretvalue(v) then
        return nil
    end
    return v
end

local function IsUnitIdentitySecret(unit)
    if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldUnitIdentityBeSecret, unit)
        if ok and secret then
            return true
        end
    end
    local name = UnitName(unit)
    if issecretvalue and type(issecretvalue) == "function" and issecretvalue(name) then
        return true
    end
    if canaccessvalue then
        local ok, can = pcall(canaccessvalue, name)
        if ok and not can then
            return true
        end
    end
    return false
end

local function UnitFullName(unit)
    if not unit then return UNKNOWNOBJECT end
    local name, realm = UnitName(unit)
    name = SafeString(name) or UNKNOWNOBJECT
    realm = SafeString(realm)
    if not realm or realm == "" then
        local playerRealm = SafeString(PLAYER_REALM)
        if not playerRealm or playerRealm == "" then
            PLAYER_REALM = GetRealmName()
            playerRealm = SafeString(PLAYER_REALM)
        end
        realm = playerRealm or "?"
    end
    return name.."-"..realm
end

--获取成就或者统计的内容，如果未完成或统计为--则返回0(如果是hash模式应该改为Nil), 成就日期返回的是(year*13+month)*32+day,
--@param id 成就或者统计的ID
--@param isStat 表示是统计而不是成就
--@param isPlayer 为空表示获取对比的成就
local function GetAchieveOrStatById(id, isStat, isPlayer)
    local func
    --6.0以后用id负值表示成就
    if id<0 then isStat = false id = -id end
    if isStat then
        local info = isPlayer and GetStatistic(id) or GetComparisonStatistic(id)
        if not info or info=="--" then
            return 0
        elseif info:find("MoneyFrame") then
            local _, _, gold = info:find("(%d*)/TInterface\\MoneyFrame\\UI%-GoldIcon")
            return gold or 0
        else
            return tonumber(info) or info
        end
    else
        local completed, month, day, year
        if isPlayer then
            _, _, _, completed, month, day, year = GetAchievementInfo(id)
        else
            completed, month, day, year = GetAchievementComparisonInfo(id)
        end
        return completed and floor(time({year=2000+year,month=month,day=day})/86400) or 0
        --return completed and (year*13+month)*32+day or 0
    end
end

local SLOT_NAME = { "头", "项", "肩", "", "胸", "腰", "裤", "鞋", "腕", "手", "戒", "戒", "饰", "饰", "披", "武", "副", "", "", }

--GS因为使用了GetInventoryItem所以必须要有unit
local function SaveGearScore(name, unit, isPlayer)
    local player = GetPlayerData(name)
    if not player then
        player = {}
        TeamStats.db.players[name] = player
    end
    if(player) then
        local gem_info, waist_extra_slot = U1GetUnitGemInfo(unit)
        local total_enchant, has_enchant, missing_enchant = U1GetUnitEnchantInfo(unit, waist_extra_slot)
        player.gem_info = gem_info

        if(not player.gsGot) then
            --计算腐蚀 U1GetItemStats 要用
            local classID = select(3, UnitClass(unit))
            local specID = isPlayer and GetSpecializationInfo(GetSpecialization()) or GetInspectSpecialization(unit)

            local avgLevel, color, pvp, totalLevel, count, slotCount, itemLinks = U1GetInventoryLevel(unit, true)
            --debug("SaveGearScore", U1GetInventoryLevel(unit))
            if avgLevel and avgLevel > 0 then
                player.gs = avgLevel
                player.re = pvp
                player.bad = count~=slotCount --有格子没装备
                player.gsGot = true
                -- 延迟UI更新到下一帧，避免在观察回调中直接操作UI
                C_Timer.After(0, function()
                    TeamStats:UIUpdate(not isPlayer)
                end)
            end
        end
    end
end

local function SaveTalents(name, unit, isPlayer)
    local player = GetPlayerData(name)
    if not player then 
        player = {}
        TeamStats.db.players[name] = player
    end
    local inspecting = not isPlayer;
    if(inspecting)then
        local active = GetInspectSpecialization(unit)
        active = (active and active>0) and select(2, GetSpecializationInfoByID(active));
        player.talent1 = active
    else
        local active = GetActiveSpecGroup()
        active = active and GetSpecialization(false, false, active);
        active = active and select(2, GetSpecializationInfo(active));
        player.talent1 = active
    end
    player.inspected = time()
    -- 延迟UI更新到下一帧，避免在观察回调中直接操作UI
    C_Timer.After(0, function()
        TeamStats:UIUpdate()
        TeamStats:SetStatusText("已获得["..(player.name or name or UNKNOWNOBJECT).."]的天赋和GS")
    end)
end

local function SaveAchievements(name, unit, isPlayer)
    --只要对比了就可以获取, 不必担心unit失效的问题, 只有GS需要
    local player = TeamStats.db.players[name]
    if not player then
        player = {}
        TeamStats.db.players[name] = player
    end
    local list = {}
    for i, id in ipairs(TeamStats.db.map) do
        list[i] = GetAchieveOrStatById(id, true, isPlayer) --TeamStats.stats[id] 目前只支持统计不支持成就
    end
    player.stats = list
    player.compared = time()
    TeamStats:UIUpdate()
    TeamStats:SetStatusText("已获得["..(player.name or name or UNKNOWNOBJECT).."]的成就资料") --TODO: 纳闷，只有一个人然后不停点清除缓存就出这个错
end

function TeamStats:TransformMythicSummary(summary)
    --C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    if not summary or not summary.runs then return end
    local tbl = {}
    for _, v in ipairs(summary.runs) do
        local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(v.mapScore) or HIGHLIGHT_FONT_COLOR
        local levelText = format(v.finishedSuccess and "|cff00ff00%d|r" or "|cff7f7f7f%d|r", v.bestRunLevel or 0)
        tbl[v.challengeModeID] = format("%s(%s)", color:WrapTextInColorCode(v.mapScore), levelText)
    end
    return tbl
end


function TeamStats:OnInitialize()
    local f = CreateFrame("Frame")
    CoreDispatchEvent(f, TeamStats);

    f:RegisterEvent("VARIABLES_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("UNIT_NAME_UPDATE")
    f:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("UNIT_INVENTORY_CHANGED")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

function TeamStats:DEFAULT_EVENT(event, ...)
    debug(event, ...)
end

function TeamStats:PLAYER_LOGIN()
    self:StartCheckTimer(CHECK_DELAY)
end

function TeamStats:UNIT_INVENTORY_CHANGED(event, unitId)
    if IsUnitIdentitySecret(unitId) then
        return
    end
    local player = TeamStats.db.players[UnitFullName(unitId)]
    if player then
        player.inspected = false
        player.gsGot = false
        self:StartCheckTimer(1)
    end
end

function TeamStats:PLAYER_EQUIPMENT_CHANGED(event, unitId)
    self:UNIT_INVENTORY_CHANGED(event, "player")
end

function TeamStats:PLAYER_SPECIALIZATION_CHANGED(event, unit)
    return TeamStats:UNIT_INVENTORY_CHANGED(event, unit)
end

function TeamStats:GROUP_ROSTER_UPDATE()
    -- 离队再加入时,清空上次队伍信息. --solo初始为nil, 这样/rl后仍能保持最近离队的队员而不会触发新队伍的清理
    if not IsInGroup() then
        TeamStats.solo = true
    else
        if TeamStats.solo then
            TeamStats.solo = nil
            for name, _ in pairs(TeamStats.names) do
                TeamStats.names[name] = nil
                TeamStats.temp_data[name] = nil
            end
        end
    end
    self:StartUpdateNameTimer(0.2)
end

TeamStats.UNIT_NAME_UPDATE = TeamStats.GROUP_ROSTER_UPDATE
TeamStats.UNIT_PORTRAIT_UPDATE = TeamStats.GROUP_ROSTER_UPDATE

function TeamStats:VARIABLES_LOADED()
    TeamStats.db = TeamStatsDB
    if TeamStats.db == nil or not TeamStats.db.VERSION or TeamStats.db.VERSION < 20170301 then
        TeamStats.db = TeamStats:GetDefaultDB()
    end
    TeamStatsDB = TeamStats.db
    TeamStats.db.names = TeamStats.db.names or TeamStats.names
    TeamStats.names = TeamStats.db.names

    -- 12.0+ 修复：SavedVariables 加载的表可能被标记为 secure table
    -- 复制到一个新普通表中，避免 "cannot be indexed with secret keys" 错误
    local oldPlayers = TeamStats.db.players
    TeamStats.db.players = {}
    for k, v in pairs(oldPlayers) do
        TeamStats.db.players[k] = v
    end

    self:ReMapData()

    --清理过期数据，最多保持2天
    local now = time()
    for k, v in pairs(TeamStats.db.players) do
        if not v.compared or now - v.compared > MAX_KEEP_DAYS*24*60*60 then
            TeamStats.db.players[k] = nil
        end
    end

    self:GROUP_ROSTER_UPDATE()
    --TeamStats:UIShow()
    if TeamStatsUI_CreateMinimapButton then TeamStatsUI_CreateMinimapButton() end
end

function TeamStats:PLAYER_REGEN_DISABLED()
    TeamStats:SetStatusText(L["StatusPaused"]);
    -- 取消所有正在进行的观察请求，避免战斗中污染ActionButton
    if self.comparing then
        self.comparing = false
    end
    -- 清除InspectLess的状态
    if InspectLess and InspectLess.GetUnit and InspectLess:GetUnit() then
        InspectLess.origins["ClearInspectPlayer"]()
    end
end

function TeamStats:PLAYER_REGEN_ENABLED()
    if TeamStats.queueForNameUpdate then
        TeamStats:StartUpdateNameTimer(CHECK_DELAY) --including StartCheckTimer
        TeamStats.queueForNameUpdate = nil
    else
        TeamStats:StartCheckTimer(CHECK_DELAY)
    end
end


--团员有变化时直接发起请求,随便设置一个时间,可以起到Bucket的作用
--查找有变化的玩家, 同时修改TeamStats.names

--需要判断names在不在列表里
local party_units, raid_units = {"player"}, {}
for i=1, MAX_PARTY_MEMBERS do table.insert(party_units, "party"..i) end
for i=1, MAX_RAID_MEMBERS do table.insert(raid_units, "raid"..i) end
local current_names = {} --当前团队成员名称, 用来跟老的做比较
function TeamStats:OnUpdateNameTimer()
    --print("OnUpdateNameTimer")
    self.updateNameTimer = nil
    table.wipe(current_names)
    local units = IsInRaid() and raid_units or party_units
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            if IsUnitIdentitySecret(unit) then
                -- 无法安全读取身份时，用“未知目标”占位，避免直接隐藏该成员
                local placeholderKey = UNKNOWN_TARGET.."-"..unit
                local player = TeamStats.db.players[placeholderKey]
                if not player then
                    player = {}
                    TeamStats.db.players[placeholderKey] = player
                end
                player.name = UNKNOWN_TARGET
                player.unknown = true
                current_names[placeholderKey] = true
            else
                if UnitName(unit) == UNKNOWNOBJECT or not UnitClass(unit) then
                    self:StartUpdateNameTimer(0.2)
                    return
                end
                local fullname = UnitFullName(unit)
                local player = TeamStats.db.players[fullname]
                if not player then 
                    player = {} 
                    TeamStats.db.players[fullname] = player 
                end
                player.name = UnitName(unit)
                player.heath = UnitHealthMax(unit)
                player.class = select(2, UnitClass(unit))
                local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
                TeamStats.temp_data[fullname] = TeamStats.temp_data[fullname] or {}
                TeamStats.temp_data[fullname]["mythic"] = TeamStats:TransformMythicSummary(summary)
                player.mscore = summary and summary.currentSeasonScore or player.mscore
                current_names[fullname] = true
            end
        end
    end

    for name, _ in pairs(TeamStats.names) do
        if not current_names[name] then
            TeamStats.names[name] = false
        end
    end

    local now = time()
    for name, _ in pairs(current_names) do
        --新加入团队的, 强制将gs和天赋标记清除, 但成就就不清了
        if not TeamStats.names[name] then
            local player = TeamStats.db.players[name]
            if player.inspected and now - player.inspected > 60*60 then
                player.inspected = false
                player.gsGot = false
            end
        end
        TeamStats.names[name] = true
        current_names[name] = nil
    end

    if(false and DEBUG_MODE) then
        for k,v in pairs(TeamStats.db.players) do
            TeamStats.names[k] = true
        end
    end

    self:StartCheckTimer(0.2)
    TeamStats:UIUpdateNames()
end

function TeamStats:GetDefaultDB()
    local version, build  = GetBuildInfo()
    local db = {
        VERSION = TeamStats.DATA_VERSION, --用来快速比较版本
        minimapPos = 354,
        players = {
            --保存各个玩家的所有成就信息, NAME-REALM
                --stats
                --gs
                --name
                --class
                --talent1
                --talent2
                --inspected 观察时间
                --compared 比较时间
                --gsGot
                --re 韧性
                --bad 是否有未装备的
        }
    }
    return db
end

--当类型页被修改的时候，重建所有数据
--同时设置TeamStats.mirror
function TeamStats:ReMapData()
    local oldMap = TeamStats.db.map
    local mapping = {} --保存成就ID和序号的对应关系
    for _, tab in ipairs(TABS) do
        for _, id in ipairs(tab.ids or {}) do
            if type(id) == "table" then
                for _, iid in ipairs(id) do
                    if type(iid) == "table" then
                        for _, iiid in ipairs(iid) do
                            mapping[#mapping+1] = iiid
                        end
                    else
                        mapping[#mapping+1] = iid
                    end
                end
            else
                mapping[#mapping+1] = id
            end
        end
    end
    for i=1, #VBOSSES, 2 do
        mapping[#mapping+1] = VBOSSES[i]
    end

    table.sort(mapping)

    --重建数据
    local rebuild = false
    if oldMap == nil then
        assert(#TeamStats.db.players==0, "Mapping info is missing, this should not happen.")
        table.wipe(TeamStats.db.players)
        rebuild = true
    else
        for i,id in ipairs(oldMap) do
            if mapping[i]~=id then
                rebuild = true
                break
            end
        end
    end

    if rebuild then
        --使用新的映射
        TeamStats.db.map = mapping

        local oldStats = {} --将信息数组转回为hash
        for _, player in pairs(TeamStats.db.players) do
            if player.stats then
                table.wipe(oldStats)
                for i, value in ipairs(player.stats) do
                    if oldMap[i] then oldStats[oldMap[i]] = value end
                end
                for i, id in ipairs(mapping) do
                    local value = oldStats[id]
                    if value == nil then
                        --有新增加的项目
                        player.stats[i] = 0 --保持array
                        player.compared = nil
                    else
                        player.stats[i] = value
                    end
                end
            end
        end
        oldStats = nil
    else
        mapping = nil
    end

    TeamStats.mirror = TeamStats.mirror or {}
    table.wipe(TeamStats.mirror)
    for i=1,#TeamStats.db.map do
        TeamStats.mirror[TeamStats.db.map[i]] = i
    end
end

--检查团队的计时器, 当玩家登入或者队伍成员发生变动时启动
function TeamStats:StartCheckTimer(delay)
    self.checkTimer = self.checkTimer or self:ScheduleTimer("OnCheck", delay)
end
--延迟更新名称
function TeamStats:StartUpdateNameTimer(delay)
    if InCombatLockdown() then
        self.queueForNameUpdate = true;
    else
        self.updateNameTimer = self.updateNameTimer or self:ScheduleTimer("OnUpdateNameTimer", delay)
    end
end

--到时间时的检查
--这两个是缓存字符串
function TeamStats:OnCheck()
    --因为需要在战斗结束后重新startTimer所以必须设置为nil
    self.checkTimer = nil --标记timer不再运行,无法用AceTimer来判断timer是否在运行, 因为它重复利用table

    if InCombatLockdown() then
        TeamStats:PLAYER_REGEN_DISABLED();
        return
    end

    local units = IsInRaid() and raid_units or party_units

    local allDone = true --表示是否需要更新数据, 如果不需要则中止循环了
    local gotOne = false --表示本轮循环是否发起了一次请求
    for i=1, #units do
        local unit = units[i]
        if not UnitExists(unit) then break end

        if IsUnitIdentitySecret(unit) then
            -- 身份受保护的团员无法安全读取名字/职业/评分/观察，跳过
        else
            local name = UnitFullName(unit)
            local curr = TeamStats.db.players[name]
            if not curr then
                curr = {}
                TeamStats.db.players[name] = curr
            end
            local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
            curr.mscore = summary and summary.currentSeasonScore or curr.mscore

            if UnitIsUnit("player", unit) then
                --玩家自身不需要观察直接获取
                if not curr.inspected then
                    gotOne = true;
                    SaveTalents(name, unit, true)
                    SaveGearScore(name, unit, true)
                end
                
                if not curr.compared then
                    gotOne = true;
                    SaveAchievements(name, unit, true)
                end

            else
                if not curr.compared then
                    allDone = false
                    --正在比较的话就不比了
                    if self:CanCompare(unit) then
                        gotOne = true;
                        if not self.comparing then
                            -- 12.1临时禁用：暴雪AchievementFrameComparison_UpdateStatusBars
                            -- 会把"summary"当categoryID传给GetCategoryNumAchievements报错
                            -- self.comparing = name
                            -- self.comparingUnit = unit
                            -- RequestProtection:Call("SetAchievementComparisonUnit", unit, self.CompareCallback);
                            --发起请求，不成功就下次再说
                        end
                    end
                end

                if not curr.inspected then
                    allDone = false
                    if InspectLess:IsNotBlocking() and (InspectLess:IsReady() or not InspectLess:GetGUID()) then
                        if self:CanInspect(unit) then
                            gotOne = true;
                            InspectLess:SafeNotifyInspect(unit, false)  -- 使用安全观察接口，避免污染ActionButton
                        end
                    end
                end
            end
        end
    end

    if allDone then
        --debug("All done")
        TeamStats:SetStatusText(L["StatusAllDone"]);
    else
        --继续检查
        TeamStats:StartCheckTimer(CHECK_INTERVAL)
        TeamStats:SetStatusText(gotOne and L["StatusGetting"] or L["StatusCannotGet"]);
    end
end

--是否可以比较成就或观察的保护条件, 因为有两处要用到
function TeamStats:CanCompare(unit)
    if IsUnitIdentitySecret(unit) then
        return false
    end
    return (not AchievementFrame or not AchievementFrameComparison:IsVisible()) and UnitIsVisible(unit)
end
function TeamStats:CanInspect(unit)
    if IsUnitIdentitySecret(unit) then
        return false
    end
    return (not InspectFrame or not InspectFrame:IsShown()) and (not Examiner or not Examiner:IsShown()) and UnitIsVisible(unit) and CanInspect(unit)
end

local i = 1
function TeamStats.CompareCallback(success, cause, ...)
    if success then
        SaveAchievements(TeamStats.comparing, TeamStats.comparingUnit, false)
    end
    TeamStats.comparing = false
end

function TeamStats:OnEnable()
end

TeamStats:OnInitialize()

function TeamStats:InspectLess_InspectItemReady(event, unit, guid)
    if IsUnitIdentitySecret(unit) then
        return
    end
    local name = UnitFullName(unit)
    --debug("InspectItemReady", unit, TeamStats.names[name])
    if TeamStats.names[name] ~= nil then
        SaveGearScore(name, unit, false)
    end
end

--不管是谁发起的观察,只要是当前团队的成员就记录
function TeamStats:InspectLess_InspectReady(event, unit, guid, done)
    --debug(event, unit, guid, unit and UnitFullName(unit) and TeamStats.names[UnitFullName(unit)])
    if unit and not IsUnitIdentitySecret(unit) then
        local name = UnitFullName(unit)
        if TeamStats.names[name] ~= nil then
            SaveTalents(name, unit, false)
        end
    end
end


InspectLess.RegisterCallback(TeamStats, "InspectLess_InspectItemReady")
InspectLess.RegisterCallback(TeamStats, "InspectLess_InspectReady")
