U1PLUG["daojishi"] = function()
-- ─── 随机倒计时 ───────────────────────────────
-- fraction: 1.0=绿色  0.5=黄色  0.25=橙色  0.0=红色
local function GetGradientRGB(fraction)
    fraction = math.max(0, math.min(1, fraction))
    if fraction >= 0.5 then
        local t = (1 - fraction) * 2
        return t, 1, 0                     -- 绿→黄
    elseif fraction >= 0.25 then
        local t = (0.5 - fraction) * 4
        return 1, 1 - t * 0.5, 0          -- 黄→橙
    else
        local t = fraction * 4
        return 1, t * 0.5, 0              -- 橙→红
    end
end

local function RGBToHex(r, g, b)
    return string.format("%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end

local function ColoredText(r, g, b, text)
    return string.format("|cff%s%s|r", RGBToHex(r, g, b), text)
end

local function FormatMMSS(seconds)
    if not seconds or seconds < 0 then return "--:--" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

-- ─── 核心：设置弹窗倒计时文字（统一底部边框外） ─────
local function SetProposalTimerText(dialog, secs)
    if not dialog or not dialog:IsShown() then return end
    
    secs = math.max(1, secs)
    local fraction = secs / 40
    local r, g, b = GetGradientRGB(fraction)
    
    -- 创建或获取倒计时标签
    if not dialog.bqtTimerLabel then
        local font, _, flags = GameFontNormalSmall:GetFont()
        dialog.bqtTimerLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dialog.bqtTimerLabel:SetFont(font, 16, "OUTLINE")
        dialog.bqtTimerLabel:SetWidth(dialog:GetWidth() - 16)
        dialog.bqtTimerLabel:SetJustifyH("CENTER")
    end
    
    -- 强制设置锚点：紧贴对话框底部边框外侧（顶部紧贴底部，无偏移）
    local label = dialog.bqtTimerLabel
    label:ClearAllPoints()
    label:SetPoint("TOP", dialog, "BOTTOM", 0, 0)  -- 0偏移 = 紧贴底部边框外
    label:Show()
    
    local timerStr = ColoredText(r, g, b, "[" .. FormatMMSS(math.floor(secs)) .. "]")
    dialog.bqtTimerLabel:SetText("到期时间 " .. timerStr)
end

-- 状态变量
local proposalActive = false
local proposalTimeLeft = 40
local pvpProposalActive = false
local pvpProposalTimeLeft = 40
local confirmQueueIndex = 0

-- 更新帧（每帧执行）
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(_, elapsed)
    -- LFG 弹窗倒计时
    if proposalActive then
        proposalTimeLeft = proposalTimeLeft - elapsed
        if proposalTimeLeft > 0 then
            SetProposalTimerText(LFGDungeonReadyDialog, proposalTimeLeft)
        else
            if LFGDungeonReadyDialog and LFGDungeonReadyDialog.bqtTimerLabel then
                LFGDungeonReadyDialog.bqtTimerLabel:Hide()
            end
        end
    end
    
    -- PvP 弹窗倒计时
    if pvpProposalActive then
        local realSecs = 0
        if confirmQueueIndex > 0 then
            local expireSecs = GetBattlefieldPortExpiration(confirmQueueIndex)
            if expireSecs and expireSecs > 0 then
                realSecs = expireSecs
            end
        end
        
        if realSecs > 0 then
            pvpProposalTimeLeft = realSecs
        else
            pvpProposalTimeLeft = pvpProposalTimeLeft - elapsed
        end
        
        if pvpProposalTimeLeft > 0 then
            SetProposalTimerText(PVPReadyDialog, pvpProposalTimeLeft)
        else
            pvpProposalActive = false
            if PVPReadyDialog and PVPReadyDialog.bqtTimerLabel then
                PVPReadyDialog.bqtTimerLabel:Hide()
            end
        end
    end
end)

-- ─── 事件监听 ─────────────────────────────────
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
eventFrame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
eventFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
eventFrame:RegisterEvent("LFG_PROPOSAL_DONE")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "LFG_PROPOSAL_SHOW" then
        proposalActive = true
        proposalTimeLeft = 40
        
    elseif event == "LFG_PROPOSAL_SUCCEEDED"
        or event == "LFG_PROPOSAL_FAILED"
        or event == "LFG_PROPOSAL_DONE" then
        proposalActive = false
        proposalTimeLeft = 40
        
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        local maxQueues = GetMaxBattlefieldQueues and GetMaxBattlefieldQueues() or 6
        local foundConfirm = false
        
        for i = 1, maxQueues do
            local status = GetBattlefieldStatus(i)
            if status == "confirm" then
                foundConfirm = true
                confirmQueueIndex = i
                local expireSecs = GetBattlefieldPortExpiration(i)
                if expireSecs and expireSecs > 0 then
                    pvpProposalActive = true
                    pvpProposalTimeLeft = expireSecs
                else
                    pvpProposalActive = true
                    pvpProposalTimeLeft = 40
                end
                break
            end
        end
        
        if not foundConfirm then
            pvpProposalActive = false
            confirmQueueIndex = 0
        end
    end
end)

end