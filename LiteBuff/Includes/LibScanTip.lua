local VERSION = 1.03

local type = type
local strfind = strfind
local _G = _G

local TIPNAME = "LibScanTip_TooltipFrame"
local TIPOWNER = WorldFrame

-- FIXED: was checking undefined variable 'tip' instead of 'tooltip'
local tooltip = _G[TIPNAME]
if type(tooltip) == "table" then
    local version = tooltip._libversion
    if type(version) == "number" and version >= VERSION then
        return
    end
    -- Old version exists; reuse the frame but reset scripts
else
    tooltip = CreateFrame("GameTooltip", TIPNAME, TIPOWNER, "GameTooltipTemplate")
end

tooltip._libversion = VERSION
tooltip:SetScript("OnShow", function(self) self._tipshown = 1 end)
tooltip:SetScript("OnHide", function(self) self._tipshown = nil end)
tooltip:Hide()
tooltip:SetAlpha(0)

local lib = _G.LibScanTip
if type(lib) ~= "table" then
    lib = {}
    _G.LibScanTip = lib
end

function lib:CallMethod(method, ...)
    local func = tooltip[method]
    if type(func) ~= "function" then
        return
    end

    if not tooltip._tipshown then
        tooltip:SetOwner(TIPOWNER, "ANCHOR_NONE")
    end

    tooltip:ClearLines()
    local ok, ret1, ret2, ret3, ret4 = pcall(func, tooltip, ...)
    -- Always hide after scanning to prevent tooltip from staying active
    tooltip:Hide()
    if ok then
        return 1, ret1, ret2, ret3, ret4
    end
end

function lib:NumLines()
    return tooltip:NumLines()
end

local PREFIX_LEFT = TIPNAME.."TextLeft"
local PREFIX_RIGHT = TIPNAME.."TextRight"

function lib:GetText(line, right)
    local fontstring = _G[(right and PREFIX_RIGHT or PREFIX_LEFT)..line]
    if fontstring then
        local text = fontstring:GetText()
        local r, g, b = fontstring:GetTextColor()
        return text, r, g, b
    end
end

function lib:FindText(text, wholematch, startline, endline, right)
    if type(text) ~= "string" or text == "" then
        return
    end

    if type(startline) ~= "number" or startline < 1 then
        startline = 1
    end

    local maxline = tooltip:NumLines()
    if type(endline) ~= "number" or endline > maxline then
        endline = maxline
    end

    for i = startline, endline do
        local line = self:GetText(i, right)
        if line then
            if wholematch then
                if line == text then
                    return line, i
                end
            else
                local _, _, content = strfind(line, text)
                if content then
                    return content, i
                end
            end
        end
    end
end