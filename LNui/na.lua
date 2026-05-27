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

for _, Bufficon in ipairs(BuffFrame.auraFrames) do
    hooksecurefunc(Bufficon, "Update", BuffMaster_81244f624fe0b105f47a78834d1c8775);
end
for _, DeBufficon in ipairs(DebuffFrame.auraFrames) do
    if DeBufficon.OnUpdate then
        hooksecurefunc(DeBufficon, "Update", BuffMaster_81244f624fe0b105f47a78834d1c8775);
    end
end

end