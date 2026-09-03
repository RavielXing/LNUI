local _, LiteBuff = ...
local L = LiteBuff.L

local iconID = C_Spell.GetSpellInfo(150544).iconID

local button = LiteBuff:CreateActionButton('IntelliMount', '智能坐骑', nil, nil, 'DUAL')
button:SetFlyProtect('type1', 'macro', 'type2', 'macro')
button.icon:SetIcon(iconID)

button.OnTooltipText = function(self, tooltip)
    GameTooltip:AddLine(L["left click"]..'智能坐骑', 1, 1, 1, 1)
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

-- 12.1 优化: 分离静态数据和运行动态数据，避免 mountsData 无限膨胀
local staticMountsData = {}
for _, v in ipairs(utilityMounts) do
    staticMountsData[v.id] = v
end

-- 运行时动态数据，每次更新前会清空，防止内存泄漏
local dynamicMountsData = {}
local gotMountsData = false
local maw = {}
local chosen = {}
local delay_timer = 0

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

-- 登入及关闭坐骑收藏时触发
local function UpdateMountsData()
    local count = C_MountJournal.GetNumMounts()
    table.wipe(maw)
    table.wipe(dynamicMountsData)  -- 12.1 优化: 清空旧动态数据，防止内存泄漏

    if count > 0 then gotMountsData = true end

    for i = 1, count do
        local creatureName, spellId, icon, active, summonable, source, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i)
        if creatureName and not hideOnChar and isCollected then
            -- 收藏的特殊坐骑 - 会的特殊坐骑 - 普通坐骑
            if (staticMountsData[spellId] or isFavorite) and summonable then
                -- 12.1 优化: 只存储动态数据，静态属性引用 staticMountsData
                dynamicMountsData[spellId] = {
                    owned = 1,
                    favorite = isFavorite,
                    index = i,
                    mountID = mountID,
                }
                -- 合并静态属性
                if staticMountsData[spellId] then
                    for k, v in pairs(staticMountsData[spellId]) do
                        if k ~= "id" then
                            dynamicMountsData[spellId][k] = v
                        end
                    end
                else
                    dynamicMountsData[spellId].normal = 1
                end

                local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType = C_MountJournal.GetMountInfoExtraByID(mountID)
                if mountType == 230 or mountType == 269 or mountType == 284 then
                    dynamicMountsData[spellId].groundOnly = 1
                end
                if mountType == 407 then
                    dynamicMountsData[spellId].normalFlyOnly = 1
                end
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

function LBIntelliMountSummon(utility, delay)
    if not gotMountsData then UpdateMountsData() end
    if IsFlying() then U1Message("正在飞行, 请珍惜生命……") return end

    local nofly = false
    if utility == "nofly" then
        nofly = true
        utility = "normal"
    end

    -- 游泳时自动判断是否使用飞行坐骑还是水面坐骑
    if not delay and utility == "normal" then
        local now = GetTime()
        if now - delay_timer < 0.2 then
            CoreCancelBucket("IntelliMountDelay")
            utility = "surface"
        else
            delay_timer = now
            return C_Timer.After(0.2, function()
                LBIntelliMountSummon("normal", "delay")
            end)
        end
    end

    delay_timer = 0
    table.wipe(chosen)

    -- 检索收藏的坐骑
    for id, data in pairs(dynamicMountsData) do
        if utility and data[utility] and data.favorite then
            table.insert(chosen, id)
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

    -- 如果区域可以飞行，而且收藏的里面有非groundOnly的，则去掉
    if #chosen > 0 and IsFlyableArea() then
        local hasFlyingFav = false
        local FlyingModeOpen = GetFlyingModeOpen()

        for _, id in ipairs(chosen) do
            if not dynamicMountsData[id].groundOnly then
                hasFlyingFav = true
                break
            end
        end

        -- 移除groundOnly的
        if hasFlyingFav then
            for i = #chosen, 1, -1 do
                local data = dynamicMountsData[chosen[i]]
                if data.groundOnly or (FlyingModeOpen and data.normalFlyOnly) then
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
