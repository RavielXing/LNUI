U1PLUG["88Movie"] = function()
-- ==========================================
-- 跳过所有过场动画
-- ==========================================

local skipAllAnimations = CreateFrame("Frame")
skipAllAnimations:RegisterEvent("CINEMATIC_START")
skipAllAnimations:RegisterEvent("PLAY_MOVIE")

skipAllAnimations:SetScript("OnEvent", function(_, event)
    if event == "CINEMATIC_START" then
        CinematicFrame_CancelCinematic()
        print("|TInterface/AddOns/LNui/Media/laonong:20|t|cff19CCF9[老农整合包]:|r 已跳过动画！")
    elseif event == "PLAY_MOVIE" then
        if MovieFrame and MovieFrame.StopMovie then
            MovieFrame:StopMovie()
        end
        print("|TInterface/AddOns/LNui/Media/laonong:20|t|cff19CCF9[老农整合包]:|r 已跳过动画！")
    end
end)

end