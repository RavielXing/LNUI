U1PLUG["daojishi"] = function()
-- ─── 随机倒计时 ───────────────────────────────
local function GetGradientRGB(fraction)
    fraction = math.max(0, math.min(1, fraction))
    if fraction >= 0.5 then
        local t = (1 - fraction) * 2
        return t, 1, 0
    elseif fraction >= 0.25 then
        local t = (0.5 - fraction) * 4
        return 1, 1 - t * 0.5, 0
    else
        local t = fraction * 4
        return 1, t * 0.5, 0
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

local function SetProposalTimerText(dialog, secs)
    if not dialog or not dialog:IsShown() then return end
    if secs <= 0 then return end

    if not dialog.bqtProgressBar then
        local container = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        container:SetWidth(dialog:GetWidth() - 16)
        container:SetHeight(22)
        container:SetFrameLevel(dialog:GetFrameLevel() + 1)
        
        container:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        container:SetBackdropColor(0, 0, 0, 0.8)
        container:SetBackdropBorderColor(1, 1, 1, 1)
        
        dialog.bqtProgressBarContainer = container

        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -4)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 4)

        local castingBarTex = PlayerCastingBarFrame and PlayerCastingBarFrame:GetStatusBarTexture()
        if castingBarTex then
            bar:SetStatusBarTexture(castingBarTex)
        else
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        end
        
        bar:SetMinMaxValues(0, secs)
        bar:SetValue(secs)
        bar:SetFrameLevel(container:GetFrameLevel() + 1)
        dialog.bqtProgressBar = bar
        dialog.bqtMaxSecs = secs
    end
    local container = dialog.bqtProgressBarContainer
    local bar = dialog.bqtProgressBar
    container:ClearAllPoints()
    container:SetPoint("TOP", dialog, "BOTTOM", 0, 5) -- 位置调整
    container:Show()
    bar:Show()

    bar:SetValue(secs)
    local maxVal = dialog.bqtMaxSecs or 40
    local fraction = (maxVal > 0) and (secs / maxVal) or 0
    local r, g, b = GetGradientRGB(fraction)
    bar:SetStatusBarColor(r, g, b)

    if not dialog.bqtTimerLabel then
        local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local font, _, flags = GameFontNormalSmall:GetFont()
        label:SetFont(font, 13, "OUTLINE") -- 字体调整
        label:SetWidth(bar:GetWidth())
        label:SetJustifyH("CENTER")
        label:SetPoint("CENTER", bar, "CENTER", 0, 0)
        dialog.bqtTimerLabel = label
    end
    local label = dialog.bqtTimerLabel
    label:Show()

    local timerStr = ColoredText(r, g, b, "[" .. FormatMMSS(math.floor(secs)) .. "]")
    label:SetText("到期时间 " .. timerStr)
end

local proposalActive = false
local proposalTimeLeft = 40
local pvpProposalActive = false
local pvpProposalTimeLeft = 40
local confirmQueueIndex = 0

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(_, elapsed)
    if proposalActive then
        proposalTimeLeft = proposalTimeLeft - elapsed
        if proposalTimeLeft > 0 then
            SetProposalTimerText(LFGDungeonReadyDialog, proposalTimeLeft)
        else
            if LFGDungeonReadyDialog then
                if LFGDungeonReadyDialog.bqtTimerLabel then
                    LFGDungeonReadyDialog.bqtTimerLabel:Hide()
                end
                if LFGDungeonReadyDialog.bqtProgressBarContainer then
                    LFGDungeonReadyDialog.bqtProgressBarContainer:Hide()
                end
            end
        end
    end

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
            if PVPReadyDialog then
                if PVPReadyDialog.bqtTimerLabel then
                    PVPReadyDialog.bqtTimerLabel:Hide()
                end
                if PVPReadyDialog.bqtProgressBarContainer then
                    PVPReadyDialog.bqtProgressBarContainer:Hide()
                end
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