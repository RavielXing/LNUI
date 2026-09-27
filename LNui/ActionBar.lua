U1PLUG["ActionBar"] = function()

local ACTION_BARS = {
    "Action",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "PetAction"
}

local function HideActionBarButtonNames()
    for i = 1, #ACTION_BARS do
        for j = 1, 12 do
            local nameText = _G[ACTION_BARS[i] .. "Button" .. j .. "Name"]
            if nameText then
                nameText:SetAlpha(0)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", HideActionBarButtonNames)

end