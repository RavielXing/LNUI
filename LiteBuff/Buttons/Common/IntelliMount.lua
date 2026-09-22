local _, LiteBuff = ...
local L = LiteBuff.L

local iconID = C_Spell.GetSpellInfo(150544).iconID

local button = LiteBuff:CreateActionButton('IntelliMount', '智能坐骑', nil, nil, 'DUAL')
button:SetFlyProtect('type1', 'macro', 'type2', 'macro')
button.icon:SetIcon(iconID)

button.OnTooltipText = function(self, tooltip)
    GameTooltip:AddLine(L["left click"]..L["intelli favorite mount"], 1, 1, 1, 1)
    GameTooltip:AddLine(L["right click"]..'载客坐骑', 1, 1, 1, 1)
    GameTooltip:AddLine('中键: 特色坐骑', 1, 1, 1, 1)
    GameTooltip:AddLine("ALT-"..L["left click"]..'修理坐骑', 1, 1, 1, 1)
    GameTooltip:AddLine("ALT-"..L["right click"]..'水下坐骑', 1, 1, 1, 1)
    GameTooltip:AddLine("ALT-中键: 取消坐骑", 1, 1, 1, 1)
    GameTooltip:AddLine("SHT-"..L["left click"]..'拍卖坐骑', 1, 1, 1, 1)
    GameTooltip:AddLine("SHT-"..L["right click"]..'幻化坐骑', 1, 1, 1, 1)
    GameTooltip:AddLine("CTL-"..L["left click"]..'地面坐骑', 1, 1, 1, 1)
    GameTooltip:AddLine("CTL-"..L["right click"]..'邮箱坐骑', 1, 1, 1, 1)
end

button:SetAttribute('type1', 'macro')
button:SetAttribute('type2', 'macro')
button:SetAttribute('type3', 'macro')
button:SetAttribute('alt-type1', 'macro')
button:SetAttribute('alt-type2', 'macro')
button:SetAttribute('alt-type3', 'macro')
button:SetAttribute('shift-type1', 'macro')
button:SetAttribute('shift-type2', 'macro')
button:SetAttribute('ctrl-type1', 'macro')
button:SetAttribute('ctrl-type2', 'macro')
button:SetAttribute('macrotext1', '/run LBIntelliMountSummon("normal")')
button:SetAttribute('macrotext2', '/run LBIntelliMountSummon("passenger")')
button:SetAttribute('macrotext3', '/run LBIntelliMountSummon("surface")')
button:SetAttribute('alt-macrotext1', '/run LBIntelliMountSummon("vendor")')
button:SetAttribute('alt-macrotext2', '/run LBIntelliMountSummon("underwater")')
button:SetAttribute('alt-macrotext3', select(2, UnitClass'player') == 'DRUID' and '/cancelform\n/dismount' or '/dismount')
button:SetAttribute('shift-macrotext1', '/run LBIntelliMountSummon("auction")')
button:SetAttribute('shift-macrotext2', '/run LBIntelliMountSummon("transmog")')
button:SetAttribute('ctrl-macrotext1', '/run LBIntelliMountSummon("nofly")')
button:SetAttribute('ctrl-macrotext2', '/run LBIntelliMountSummon("mail")')

button:SetAttribute('dark_when_combat', "1")

button:SetAttribute('_onmouseup', [[
    self:ChildUpdate('onmouseup', '_onmouseup')
]])
button.OnMountStateChanged = function(self, mounted)
    self.status = mounted and "Y" or nil
    return self:UpdateStatus()
end
button:SetAttribute('_onstate-mountstate', [[
    self:CallMethod('OnMountStateChanged', newstate == 1)
]])
RegisterStateDriver(button, 'mountstate', '[mounted][flying] 1; 0')
button:SetAttribute('_onstate-combatstate', [[self:CallMethod('OnMountStateChanged', false)]])
RegisterStateDriver(button, 'combatstate', '[combat] 1; 0')

----------------------------------------------------------------
-- Code from IntelliMount/UtilityMounts.lua  by Abin 2014/10/21
-- 12.1 内存优化版: 修复 mountsData 泄漏、循环bug、全局污染
----------------------------------------------------------------
local utilityMounts = {
    { id =  30174, underwater = 1 }, --乌龟
    { id =  60424, passenger = 1 }, --机械师的摩托车，联盟的
    { id =  55531, passenger = 1 }, --机械路霸，部落的
    { id =  61447, passenger = 1, vendor = 1 }, --旅行者猛犸
    { id =  64731, underwater = 1 }, --海龟
    { id =  75973, passenger = 1 }, --火箭
    { id =  93326, passenger = 1 },  --砂石幼龙
    { id =  98718, underwater = 1 }, --驯服的海马
    { id = 121820, passenger = 1 }, --黑曜夜之翼
    { id = 122708, passenger = 1, transmog = 1, vendor = 1 }, --雄壮远足牦牛
    { id = 457485, passenger = 1, transmog = 1, vendor = 1 }, --灰熊丘陵魁熊
    { id = 1262886, surface = 1 }, --磨轮号Mk. 11型
    { id = 424607, surface = 1 },  --泰瓦恩
    { id = 42776, surface = 1 },  --幽灵虎
    { id = 42777, surface = 1 },  --迅捷幽灵虎
    { id = 473472, surface = 1 },  --加尼的垃圾堆
    { id = 440444, surface = 1 },  --佐瓦尔的噬魂者
    { id = 1293028, surface = 1 },  --螃蟹坐骑
    { id = 214791, underwater = 1 },  --深海喂食者
    { id = 223018, underwater = 1 },  --深海水母
    { id = 278979, underwater = 1 },  --拍浪水母
    { id = 300153, underwater = 1 },  --赤红浪骁
    { id = 300151, underwater = 1 },  --墨鳞觅暗者
    { id = 253711, underwater = 1 },  --池塘水母
    { id = 228919, underwater = 1 },  --暗水鳐鱼
    { id = 278803, underwater = 1 },  --无尽之海鳐鱼
    { id = 245725, passenger = 1 }, --奥格瑞玛拦截飞艇
    { id = 245723, passenger = 1 }, --暴风城逐天战机
    { id = 264058, auction = 1, vendor = 1, passenger = 1, }, --雷龙
    { id = 465235, auction = 1, mail = 1, passenger = 1, }, --鎏金雷龙
    { id = 142515, mail = 1, vendor = 1, }, --营炉者的流浪大篷车
}

-- 静态表按法术ID写, 召唤要用的却是坐骑ID, 建个反查
local staticByMountID = {}

-- 飞不起来的坐骑类型。官方没有mountTypeID枚举, 这张表是拿游戏收藏面板的"地面"筛选实测出来的:
-- 当前版本582只地面坐骑, 类型号只有230/241/284/408四种(269以前有, 日志里现在没这类坐骑了, 留着以防加回来)
-- 别往里塞水下坐骑(海马/水母那些): 有的只能在水下召唤, 陆上被随机到就白按一次
local GROUND_TYPES = {
	[230] = true, -- 常规地面坐骑(马/狼这类)
	[241] = true, -- 其拉作战坦克
	[284] = true, -- 代驾型机械路霸/摩托车
	[408] = true, -- 迅螺原型
	[269] = true, -- 水黾
}
for _, v in ipairs(utilityMounts) do
    local mountID = C_MountJournal.GetMountFromSpell(v.id)
    if mountID then
        staticByMountID[mountID] = v
    end
end

-- 运行时动态数据，每次更新前会清空，防止内存泄漏
-- 键是坐骑ID: 召唤要传给SummonByID的就是它, 而且不随收藏日志的排序/筛选变
-- 装的是所有已收藏的坐骑, favorite字段标出哪些在偏好里
local dynamicMountsData = {}
local maw = {}
local chosen = {}

-- 12.1 优化: 缓存飞行模式检测结果，减少 C_UnitAuras 调用
local flyingModeOpenCache = nil
local flyingModeOpenCacheTime = 0

local function GetFlyingModeOpen()
    local now = GetTime()
    if now - flyingModeOpenCacheTime > 2 then  -- 2秒缓存
        flyingModeOpenCache = C_UnitAuras.GetPlayerAuraBySpellID(404464)
        flyingModeOpenCacheTime = now
    end
    return flyingModeOpenCache
end

-- 在水里: 游泳或潜水都算。这俩是宏条件[swimming]/[submerged]对应的函数, 在暴雪的受限环境白名单里, 战斗中也安全
local function InWater()
    return IsSwimming() or IsSubmerged()
end

-- 登入及关闭坐骑收藏时触发
local function UpdateMountsData()
    table.wipe(maw)
    table.wipe(dynamicMountsData)

    -- 不能用GetDisplayedMountInfo: 它按展示序号取, 日志一被筛选/搜索就错位, 错位的ID喂给SummonByID是静默失败
    -- GetMountIDs给的是全部坐骑的稳定ID
    local mountIDs = C_MountJournal.GetMountIDs()
    for _, mountID in ipairs(mountIDs) do
        local creatureName, spellId, icon, active, usable, source, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected, _, isSteadyFlight = C_MountJournal.GetMountInfoByID(mountID)
        if creatureName and not hideOnChar and isCollected then
            -- 收藏的坐骑全部进缓存(不只偏好): 地面坐骑键在自己偏好里挑不到不能飞的时, 要能放宽到所有已收藏的
            local data = {
                owned = 1,
                favorite = isFavorite,
                mountID = mountID,
            }
            dynamicMountsData[mountID] = data
            -- 收藏的特殊坐骑 - 会的特殊坐骑 - 普通坐骑
            local flags = staticByMountID[mountID]
            if flags then
                for k, v in pairs(flags) do
                    if k ~= "id" then
                        data[k] = v
                    end
                end
            else
                data.normal = 1
            end

            local mountType = select(5, C_MountJournal.GetMountInfoExtraByID(mountID))
            if GROUND_TYPES[mountType] then
                data.groundOnly = 1
            end
            -- 只能稳定飞行(开不了驭空术)的坐骑: 官方布尔, 比按类型号猜可靠
            if isSteadyFlight then
                data.normalFlyOnly = 1
            end

            if mountID == 1304 or mountID == 1442 or mountID == 1441 then
                table.insert(maw, (isFavorite and -1 or 1) * mountID)
            end --渊誓猎魂犬 1304 --回廊潜行猎犬 1442 --被缚的影犬 1441
        end
    end

    -- tricky if any < 0, remove x>0 and revert x<0, else all > 0, no proc
    for i, v in ipairs(maw) do
        if v < 0 then
            -- 12.1 修复: 原代码缺少 step 参数 -1，导致死循环/逻辑错误
            for j = #maw, 1, -1 do
                if maw[j] < 0 then
                    maw[j] = -maw[j]
                else
                    table.remove(maw, j)
                end
            end
            break
        end
    end

    if SPELL_FAILED_CUSTOM_ERROR_511 and #maw > 0 and not LB_MOUNT_MAW_FRAME then
        local f = CreateFrame("Frame", "LB_MOUNT_MAW_FRAME")
        f:RegisterEvent("UI_ERROR_MESSAGE")
        f:SetScript("OnEvent", function(self, event, arg1, arg2)
            if arg2 == SPELL_FAILED_CUSTOM_ERROR_511 then
                C_MountJournal.SummonByID(maw[math.random(1, #maw)])
            end
        end)
    end
end

UpdateMountsData()

-- 收藏/可用性一变就重建, 不然缓存只在加载那一次算数
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NEW_MOUNT_ADDED")
eventFrame:RegisterEvent("COMPANION_LEARNED")
eventFrame:RegisterEvent("COMPANION_UNLEARNED")
eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")  -- 登入兜底一次就够
    end
    UpdateMountsData()
end)

-- 偏好随时能改, 但坐骑日志没有"偏好变了"的事件, 挂SetIsFavorite才知道该重建缓存
-- (不挂的话刚加进偏好的坐骑要等下次重载才抽得到)
hooksecurefunc(C_MountJournal, "SetIsFavorite", UpdateMountsData)

function LBIntelliMountSummon(utility)
    if IsFlying() then U1Message("正在飞行, 请珍惜生命……") return end

    local nofly = false
    if utility == "nofly" then
        nofly = true
        utility = "normal"
    end
    -- 已移除双击判定：快速连点直接召唤普通坐骑，不切换为特色坐骑；特色坐骑仅由中键触发
    table.wipe(chosen)

    if nofly then
        -- 地面坐骑键(CTL-左键): 只挑不能飞的, 在哪儿按都一样(这键的意思就是要地面坐骑)
        for id, data in pairs(dynamicMountsData) do
            if data.groundOnly and data.favorite then
                table.insert(chosen, id)
            end
        end
        -- 偏好里一只不能飞的都没有, 放宽到所有已收藏的; 否则会退成游戏自带的随机偏好坐骑, 跟左键没区别
        if #chosen == 0 then
            for id, data in pairs(dynamicMountsData) do
                if data.groundOnly then
                    table.insert(chosen, id)
                end
            end
        end
    else
        -- 泡在水里(游泳或潜水)优先给偏好里的水下坐骑, 没有就给只会飞的: 水里地面坐骑召不出来
        -- 只管左键; 其他键要什么坐骑是明确的, 不掺和
        if utility == "normal" and InWater() then
            for id, data in pairs(dynamicMountsData) do
                if data.underwater and data.favorite then
                    table.insert(chosen, id)
                end
            end
            if #chosen == 0 then
                for id, data in pairs(dynamicMountsData) do
                    if data.favorite and not data.groundOnly then
                        table.insert(chosen, id)
                    end
                end
            end
        end

        -- 检索收藏的坐骑
        if #chosen == 0 then
            for id, data in pairs(dynamicMountsData) do
                if utility and data[utility] and data.favorite then
                    table.insert(chosen, id)
                end
            end
        end

        -- 没有收藏的, 看下有没有未收藏的特殊坐骑
        if #chosen == 0 and utility ~= "normal" then
            for id, data in pairs(dynamicMountsData) do
                if data[utility] and data.owned then
                    table.insert(chosen, id)
                end
            end
        end
    end

    -- 可飞区域优先给会飞的: 能驭空 > 只能稳定飞行 > 地面
    -- 只有真存在更高一档的候选时才剔低一档的; 否则可能剔到空, 退成游戏自带的随机坐骑(反而随机到地面坐骑)
    if #chosen > 0 and IsFlyableArea() then
        local FlyingModeOpen = GetFlyingModeOpen()
        local hasFlyer = false   -- 有会飞的(含只能稳定飞行的)
        local hasDynamic = false -- 有开得了驭空术的

        for _, id in ipairs(chosen) do
            local data = dynamicMountsData[id]
            if not data.groundOnly then
                hasFlyer = true
                if not (FlyingModeOpen and data.normalFlyOnly) then
                    hasDynamic = true
                    break
                end
            end
        end

        if hasFlyer then
            for i = #chosen, 1, -1 do
                local data = dynamicMountsData[chosen[i]]
                if data.groundOnly or (FlyingModeOpen and hasDynamic and data.normalFlyOnly) then
                    table.remove(chosen, i)
                end
            end
        end
    end

    if #chosen == 0 then
        C_MountJournal.SummonByID(0)
    else
        local pick = chosen[math.random(1, #chosen)]
        if pick and dynamicMountsData[pick] then
            C_MountJournal.SummonByID(dynamicMountsData[pick].mountID)
        end
    end
end
