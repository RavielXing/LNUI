U1PLUG["na"] = function()

--N/A功能，作者：shray929，https://nga.178.com/read.php?tid=32246801&page=12#pid857818830Anchor
local function BuffMaster_81244f624fe0b105f47a78834d1c8775(buffIcon)
    if buffIcon.buttonInfo.expirationTime then
        local duration = buffIcon.Duration
        duration:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")	--文字大小
        duration:SetText("|cff00ff00N/A|r");
        duration:Show();
    end
end

-- 12.0/12.1 兼容：新版 BuffFrame/DebuffFrame 的 auraFrames 可能不存在，
-- 先判空再遍历，避免加载时报 ipairs 参数错误
if BuffFrame.auraFrames then
    for _, Bufficon in ipairs(BuffFrame.auraFrames) do
        hooksecurefunc(Bufficon, "Update", BuffMaster_81244f624fe0b105f47a78834d1c8775);
    end
end
if DebuffFrame.auraFrames then
    for _, DeBufficon in ipairs(DebuffFrame.auraFrames) do
        if DeBufficon.OnUpdate then
            hooksecurefunc(DeBufficon, "Update", BuffMaster_81244f624fe0b105f47a78834d1c8775);
        end
    end
end

end
