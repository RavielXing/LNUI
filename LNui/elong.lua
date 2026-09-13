U1PLUG["elong"] = function()
-- ============================================
-- 根据嗜血/英勇减益检测播放音乐
-- 修复：12.0 中 aura 闪烁导致的重复播放问题
-- ============================================

-- 创建主框架
local EnhBloodlust = CreateFrame("frame")

-- 配置设置
local config = {
    sound = {
        {"Interface/AddOns/LNui/sounds/elong.mp3", 42}
    },
    
    channel = "Master",
    enableIncreaseChannel = true,
    enableSoundCut = true,
    soundCutDuration = 42,
    enableTrueRandomize = false,
    
    -- 触发设置
    cooldown = 42,      -- 冷却时间(秒)，防止重复触发
}

-- ============================================
-- 嗜血减益ID定义
-- ============================================
local SATED_SPELL_IDS = {
    [57723] = true,   -- 筋疲力尽 (部落嗜血)
    [57724] = true,   -- 心满意足 (联盟英勇)
    [80354] = true,   -- 时空错位 (法师时间扭曲)
    [95809] = true,   -- 疯狂 (猎人宠物远古狂乱)
    [160455] = true,  -- 疲倦 (德鲁伊嗜血)
    [264689] = true,  -- 疲倦 (经典版)
    [390435] = true,  -- 筋疲力尽 (DF版本)
}

-- ============================================
-- 全局变量
-- ============================================
local isPlaying = false
local currentSoundHandle = nil
local originalSoundChannel = 0

-- 状态管理
local hasSated = false           -- 当前是否有嗜血减益
local lastTriggerTime = 0        -- 上次触发时间（冷却控制）
local playOrder = {}
local isLoginSyncDone = false    -- 登录/重载同步是否完成
local satedRemoveTimer = nil     -- 减益消失延迟确认定时器

-- ============================================
-- 音效通道管理
-- ============================================
local function IncreaseSoundChannel()
    if not config.enableIncreaseChannel then return end
    originalSoundChannel = tonumber(LNuiCompat.GetCVar("Sound_NumChannels")) or 20
    if originalSoundChannel < 128 then
        LNuiCompat.SetCVar("Sound_NumChannels", 128)
    end
end

local function RestoreSoundChannel()
    if not config.enableIncreaseChannel then return end
    LNuiCompat.SetCVar("Sound_NumChannels", originalSoundChannel)
end

-- ============================================
-- 播放顺序管理
-- ============================================
local function RefillPlayOrder()
    local soundCount = #config.sound
    if soundCount == 0 then return false end
    
    playOrder = {}
    for i = 1, soundCount do
        table.insert(playOrder, i)
    end
    
    for i = soundCount, 2, -1 do
        local j = math.random(1, i)
        playOrder[i], playOrder[j] = playOrder[j], playOrder[i]
    end
    return true
end

local function GetNextMusicIndex()
    if config.enableTrueRandomize then
        return math.random(#config.sound)
    end

    if #playOrder == 0 then
        if not RefillPlayOrder() then return nil end
    end
    return table.remove(playOrder, 1)
end

-- ============================================
-- 音乐控制
-- ============================================
local function StopCurrentSound()
    if currentSoundHandle then
        StopSound(currentSoundHandle)
        RestoreSoundChannel()
        isPlaying = false
        currentSoundHandle = nil
    end
end

-- ============================================
-- 核心检测逻辑
-- ============================================

-- 检查当前是否有嗜血减益
local function CheckHasSatedDebuff()
    for spellId in pairs(SATED_SPELL_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if aura then
            return true
        end
    end
    return false
end

-- 触发播放
local function TriggerBloodlust()
    local currentTime = GetTime()
    
    -- 检查冷却
    if currentTime - lastTriggerTime < config.cooldown then
        return false
    end
    
    -- 检查是否正在播放
    if isPlaying then
        return false
    end
    
    -- 【关键修复】最终确认：触发前再次确认减益确实存在
    -- 防止事件队列延迟导致的状态不同步
    if not CheckHasSatedDebuff() then
        return false
    end
    
    lastTriggerTime = currentTime
    
    -- 播放音乐
    IncreaseSoundChannel()
    
    local selectedIndex = GetNextMusicIndex()
    if not selectedIndex then
        RestoreSoundChannel()
        return false
    end
    
    local musicData = config.sound[selectedIndex]
    if not musicData then
        RestoreSoundChannel()
        return false
    end
    
    local willPlay, soundHandle = PlaySoundFile(musicData[1], config.channel)
    
    if willPlay then
        isPlaying = true
        currentSoundHandle = soundHandle
        
        local duration = config.enableSoundCut and config.soundCutDuration or (musicData[2] + 1)
        
        -- 播放结束后清理
        C_Timer.After(duration, function()
            StopCurrentSound()
        end)
        
        return true
    else
        RestoreSoundChannel()
        return false
    end
end

-- ============================================
-- 事件处理
-- ============================================

EnhBloodlust:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        return self[event](self, event, ...)
    end
end)

-- 初始化：延迟同步状态，防止重载界面后立即触发
EnhBloodlust:RegisterEvent("PLAYER_ENTERING_WORLD")
function EnhBloodlust:PLAYER_ENTERING_WORLD()
    isLoginSyncDone = false
    
    -- 清理可能残留的定时器
    if satedRemoveTimer then
        satedRemoveTimer:Cancel()
        satedRemoveTimer = nil
    end
    
    C_Timer.After(2, function()
        -- 同步当前状态
        hasSated = CheckHasSatedDebuff()
        
        -- 如果进入世界时已经有减益，设置冷却时间防止立即触发
        if hasSated then
            lastTriggerTime = GetTime()
        end
        
        isLoginSyncDone = true
    end)
end

-- 核心事件：检测减益变化
EnhBloodlust:RegisterEvent("UNIT_AURA")
function EnhBloodlust:UNIT_AURA(event, unit)
    if unit ~= "player" then return end
    
    local currentHasSated = CheckHasSatedDebuff()
    
    -- 登录/重载同步完成前，只更新状态，不触发播放
    if not isLoginSyncDone then
        hasSated = currentHasSated
        return
    end
    
    -- 【关键修复】状态从"无"变"有"：获得嗜血减益，触发音乐
    if currentHasSated and not hasSated then
        -- 取消可能存在的消失确认定时器
        if satedRemoveTimer then
            satedRemoveTimer:Cancel()
            satedRemoveTimer = nil
        end
        hasSated = true
        TriggerBloodlust()
    
    -- 【关键修复】状态从"有"变"无"：嗜血减益消失
    -- 不立即更新状态，而是延迟 1 秒确认
    -- 防止 12.0 中 aura 系统重建/区域切换时的"闪烁"误报
    elseif not currentHasSated and hasSated then
        if not satedRemoveTimer then
            satedRemoveTimer = C_Timer.NewTimer(1.0, function()
                -- 1秒后再次确认减益是否真的消失了
                if not CheckHasSatedDebuff() then
                    hasSated = false
                    StopCurrentSound()
                end
                -- 如果减益其实还在（闪烁），hasSated 保持 true，不会触发重复播放
                satedRemoveTimer = nil
            end)
        end
    end
end

-- 登出清理
EnhBloodlust:RegisterEvent("PLAYER_LOGOUT")
function EnhBloodlust:PLAYER_LOGOUT()
    if satedRemoveTimer then
        satedRemoveTimer:Cancel()
        satedRemoveTimer = nil
    end
    StopCurrentSound()
end

-- ============================================
-- 初始化播放顺序
-- ============================================
RefillPlayOrder()

end