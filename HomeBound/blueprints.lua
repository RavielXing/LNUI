local _, db = ...
local Blueprints = {}
db.Blueprints = Blueprints

Blueprints.Library = {}

Blueprints.ContentCache = {}
Blueprints.pendingRequestCode = nil

Blueprints.ContentTypeLabel = {
    [Enum.HousingBlueprintContentType.None]       = "Other",
    [Enum.HousingBlueprintContentType.HouseType]  = "House Type",
    [Enum.HousingBlueprintContentType.Room]       = "Rooms",
    [Enum.HousingBlueprintContentType.Decor]      = "Decor",
    [Enum.HousingBlueprintContentType.Dye]        = "Dyes",
    [Enum.HousingBlueprintContentType.Fixture]    = "Fixtures",
    [Enum.HousingBlueprintContentType.Other]      = "Other",
}

Blueprints.UnmetFlagLabel = {
    [Enum.HousingBlueprintUnmetRequirementFlags.InsufficientBudget]         = "Insufficient budget",
    [Enum.HousingBlueprintUnmetRequirementFlags.MissingRoom]                = "Missing room",
    [Enum.HousingBlueprintUnmetRequirementFlags.MissingFixture]             = "Missing fixture",
    [Enum.HousingBlueprintUnmetRequirementFlags.MissingDecor]               = "Missing decor",
    [Enum.HousingBlueprintUnmetRequirementFlags.MissingDye]                 = "Missing dye",
    [Enum.HousingBlueprintUnmetRequirementFlags.MismatchedExteriorFaction]  = "Wrong faction",
    [Enum.HousingBlueprintUnmetRequirementFlags.HouseTypeLocked]            = "House type locked",
    [Enum.HousingBlueprintUnmetRequirementFlags.HouseSizeLocked]            = "House size locked",
}

Blueprints.UnmetFlagPriority = {
    "HouseTypeLocked",
    "HouseSizeLocked",
    "MismatchedExteriorFaction",
    "InsufficientBudget",
    "MissingRoom",
    "MissingFixture",
    "MissingDecor",
    "MissingDye",
}

local function CollectActiveFlags(flags)
    local active = {}
    if not flags or flags == 0 then return active end
    for bitVal, label in pairs(Blueprints.UnmetFlagLabel) do
        if bitVal ~= 0 and bit.band(flags, bitVal) ~= 0 then
            table.insert(active, { bit = bitVal, label = label })
        end
    end
    return active
end

local function PriorityRank()
    local rank = {}
    for i, name in ipairs(Blueprints.UnmetFlagPriority) do
        local bitVal = Enum.HousingBlueprintUnmetRequirementFlags[name]
        if bitVal then rank[bitVal] = i end
    end
    return rank
end

function Blueprints.DecodeFlags(flags)
    local out = {}
    for _, item in ipairs(CollectActiveFlags(flags)) do table.insert(out, item.label) end
    table.sort(out)
    return out
end

function Blueprints.GetSortedUnmetFlags(flags)
    local active = CollectActiveFlags(flags)
    if #active == 0 then return {} end

    local rank = PriorityRank()
    table.sort(active, function(a, b)
        local ra, rb = rank[a.bit], rank[b.bit]
        if ra and rb then return ra < rb end
        if ra then return true end
        if rb then return false end
        return a.label < b.label
    end)

    local labels = {}
    for _, item in ipairs(active) do table.insert(labels, item.label) end
    return labels
end

function Blueprints.GetFirstUnmetFlag(flags)
    local labels = Blueprints.GetSortedUnmetFlags(flags)
    if #labels == 0 then return nil, 0 end
    return labels[1], #labels - 1
end

function Blueprints.FormatUnmetLine(flags)
    local labels = Blueprints.GetSortedUnmetFlags(flags)
    if #labels == 0 then return nil end
    return table.concat(labels, "   •   ")
end

function Blueprints.NormalizeEntry(raw, groupContentType, groupIndex)
    if type(raw) ~= "table" or not raw.recordID then return nil end

    local total = raw.total or 0
    local numMissing = raw.numMissing or 0

    return {
        recordID = raw.recordID,
        name = raw.name or ("Catalog #" .. tostring(raw.recordID)),
        contentType = raw.contentType or groupContentType,
        total = total,
        numMissing = numMissing,
        owned = math.max(0, total - numMissing),
        invalid = raw.invalid or false,
        tooltip = raw.tooltip,
        groupIndex = groupIndex,
    }
end

local ContentTypeToCatalogEntryType = {
    [Enum.HousingBlueprintContentType.Decor] = Enum.HousingCatalogEntryType.Decor,
    [Enum.HousingBlueprintContentType.Room]  = Enum.HousingCatalogEntryType.Room,
}

function Blueprints.TryShowCatalogTooltip(contentType, recordID)
    if not recordID then return false end

    if contentType == Enum.HousingBlueprintContentType.Dye then
        return pcall(GameTooltip.SetItemByID, GameTooltip, recordID) and true or false
    end

    local entryType = ContentTypeToCatalogEntryType[contentType]
    if not (entryType and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID) then
        return false
    end

    local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, entryType, recordID)
    if not (ok and info) then return false end

    if info.itemID and pcall(GameTooltip.SetItemByID, GameTooltip, info.itemID) then
        return true
    end

    GameTooltip:SetText(info.name or "", 1, 0.82, 0)
    if info.sourceText and info.sourceText ~= "" then
        GameTooltip:AddLine(info.sourceText, 1, 1, 1, true)
    end
    return true
end

function Blueprints.RequestContents(code, force)
    if not code or code == "" then return nil end

    local cache = Blueprints.ContentCache[code]
    if cache and cache.state == "ready" and not force then
        return cache
    end
    if cache and cache.state == "pending" and Blueprints.pendingRequestCode == code then
        return cache
    end

    if Blueprints.pendingRequestCode and Blueprints.pendingRequestCode ~= code then
        local stale = Blueprints.ContentCache[Blueprints.pendingRequestCode]
        if stale and stale.state == "pending" then
            Blueprints.ContentCache[Blueprints.pendingRequestCode] = nil
        end
    end

    cache = { state = "pending", entries = {} }
    Blueprints.ContentCache[code] = cache

    if C_HousingBlueprint and C_HousingBlueprint.IsShareCodeValid and not C_HousingBlueprint.IsShareCodeValid(code) then
        cache.state = "failed"
        cache.error = "Invalid share code"
        return cache
    end

    if not (C_HousingBlueprint and C_HousingBlueprint.RequestBlueprintContents) then
        cache.state = "failed"
        cache.error = "Blueprint API unavailable"
        return cache
    end

    Blueprints.pendingRequestCode = code
    C_HousingBlueprint.RequestBlueprintContents(code)

    return cache
end

function Blueprints.GetCache(code)
    return Blueprints.ContentCache[code]
end

function Blueprints.GetScore(bp)
    local cache = Blueprints.ContentCache[bp.code]
    if not cache or cache.state ~= "ready" then
        return nil, 0, 0
    end

    local totalRequired, totalOwned = 0, 0
    for _, entry in ipairs(cache.entries) do
        if not entry.invalid then
            local required = entry.total or 0
            totalRequired = totalRequired + required
            totalOwned = totalOwned + math.min(entry.owned or 0, required)
        end
    end

    local pct = totalRequired > 0 and (totalOwned / totalRequired) or 1
    return pct, totalOwned, totalRequired
end

local function DumpValue(v)
    if type(v) == "table" then
        if #v > 0 then
            local sample = v[1]
            if type(sample) == "table" then
                local keys = {}
                for k in pairs(sample) do table.insert(keys, tostring(k)) end
                table.sort(keys)
                return string.format("array[%d] of {%s}", #v, table.concat(keys, ", "))
            end
            return string.format("array[%d] of %s", #v, type(sample))
        end
        local keys = {}
        for k in pairs(v) do table.insert(keys, tostring(k)) end
        table.sort(keys)
        return string.format("table {%s}", table.concat(keys, ", "))
    end
    return type(v) .. (type(v) ~= "table" and (" (" .. tostring(v) .. ")") or "")
end

function Blueprints.DebugDumpContentInfo(contentInfo, label)
    print("|cffffd100Home Bound debug:|r " .. (label or "contentInfo") .. " = " .. DumpValue(contentInfo))
    if type(contentInfo) ~= "table" then return end
    for k, v in pairs(contentInfo) do
        print(string.format("  .%s -> %s", tostring(k), DumpValue(v)))
    end
    if type(contentInfo.contentGroups) == "table" then
        for gi, group in ipairs(contentInfo.contentGroups) do
            print(string.format("  .contentGroups[%d].contentType -> %s", gi, DumpValue(group.contentType)))
            if type(group.entries) == "table" and type(group.entries[1]) == "table" then
                print(string.format("  .contentGroups[%d].entries[1] raw fields:", gi))
                for ek, ev in pairs(group.entries[1]) do
                    print(string.format("      .%s -> %s", tostring(ek), DumpValue(ev)))
                end
            end
        end
    end
end

SLASH_HOMEBOUNDDEBUG1 = "/hbdump"
SlashCmdList["HOMEBOUNDDEBUG"] = function(code)
    if code then code = code:gsub("^%s+", ""):gsub("%s+$", "") end
    if not code or code == "" then
        code = Blueprints.UI and Blueprints.UI.selectedBP and Blueprints.UI.selectedBP.code
    end
    if not code then
        print("|cffffd100Home Bound:|r Usage: /hbdump <shareCode>  (defaults to the currently selected blueprint)")
        return
    end

    local existing = Blueprints.ContentCache[code]
    if existing and existing.state == "ready" and existing.rawContentInfo then
        Blueprints.DebugDumpContentInfo(existing.rawContentInfo, "cached contentInfo for " .. code)
        return
    end

    Blueprints._pendingDebugCode = code
    Blueprints.RequestContents(code, true)
    print("|cffffd100Home Bound:|r Requested contents for " .. code .. " - will dump the raw payload when it arrives.")
end

local eventFrame = CreateFrame("Frame")
Blueprints.EventFrame = eventFrame

eventFrame:RegisterEvent("HOUSING_BLUEPRINT_CONTENTS_RECEIVED")
eventFrame:RegisterEvent("HOUSING_BLUEPRINT_CONTENTS_FAILURE")
eventFrame:RegisterEvent("HOUSING_BLUEPRINT_IMPORT_SUCCESS")
eventFrame:RegisterEvent("HOUSING_BLUEPRINT_IMPORT_FAILURE")
eventFrame:RegisterEvent("HOUSING_BLUEPRINTS_AVAILABILITY_CHANGED")
eventFrame:RegisterEvent("HOUSING_STORAGE_UPDATED")
eventFrame:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

local function RefreshSelectedBlueprint()
    local UI = Blueprints.UI
    if not (UI and UI.frame and UI.frame:IsShown() and UI.selectedBP) then return end
    Blueprints.RequestContents(UI.selectedBP.code, true)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "HOUSING_BLUEPRINT_CONTENTS_RECEIVED" then
        local contentInfo = ...
        local code = contentInfo and contentInfo.shareCode
        local cache = code and Blueprints.ContentCache[code]
        if not cache then return end

        if Blueprints.pendingRequestCode == code then
            Blueprints.pendingRequestCode = nil
        end

        cache.rawContentInfo = contentInfo
        cache.budgetInfo = contentInfo.budgetInfo
        cache.unmetRequirementFlags = contentInfo.unmetRequirementFlags
        cache.blockingRequirementFlags = contentInfo.blockingRequirementFlags
        cache.targetHouseGUID = contentInfo.targetHouseGUID

        wipe(cache.entries)
        for gi, group in ipairs(contentInfo.contentGroups or {}) do
            for _, raw in ipairs(group.entries or {}) do
                local normalized = Blueprints.NormalizeEntry(raw, group.contentType, gi)
                if normalized then
                    table.insert(cache.entries, normalized)
                end
            end
        end
        cache.state = "ready"

        if Blueprints._pendingDebugCode == code then
            Blueprints.DebugDumpContentInfo(contentInfo, "contentInfo for " .. tostring(code))
            Blueprints._pendingDebugCode = nil
        end

        if Blueprints.UI and Blueprints.UI.frame and Blueprints.UI.frame:IsShown() then
            Blueprints.UpdateGallery()
        end

    elseif event == "HOUSING_BLUEPRINT_CONTENTS_FAILURE" then
        local blueprintShareCode, result = ...
        if Blueprints.pendingRequestCode == blueprintShareCode then
            Blueprints.pendingRequestCode = nil
        end
        local cache = blueprintShareCode and Blueprints.ContentCache[blueprintShareCode]
        if cache then
            cache.state = "failed"
            cache.error = result
            if Blueprints.UI and Blueprints.UI.frame and Blueprints.UI.frame:IsShown() then
                Blueprints.UpdateGallery()
            end
        end

    elseif event == "HOUSING_BLUEPRINT_IMPORT_SUCCESS" or event == "HOUSING_BLUEPRINT_IMPORT_FAILURE" then
        if Blueprints.UI and Blueprints.UI.RefreshImportButton then
            Blueprints.UI.RefreshImportButton()
        end

    elseif event == "HOUSING_BLUEPRINTS_AVAILABILITY_CHANGED" then
        if Blueprints.UI and Blueprints.UI.RefreshImportButton then
            Blueprints.UI.RefreshImportButton()
        end

    elseif event == "HOUSING_STORAGE_UPDATED"
        or event == "HOUSING_STORAGE_ENTRY_UPDATED"
        or event == "BAG_UPDATE_DELAYED" then
        RefreshSelectedBlueprint()
    end
end)

local UI = {}
Blueprints.UI = UI

local function ApplyBackdrop(f, r, g, b, a)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, a or 0.95)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

function Blueprints.Initialize()
    local frame = CreateFrame("Frame", "HB_BlueprintsFrame", HB_MainFrame)
    frame:SetPoint("TOPLEFT", 12, -90)
    frame:SetPoint("BOTTOMRIGHT", -12, 12)
    frame:Hide()

    local leftPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMLEFT", 0, 0)
    leftPanel:SetWidth(260)
    leftPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = {left=3, right=3, top=3, bottom=3}
    })
    leftPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    leftPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local rightPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    rightPanel:SetPoint("TOPRIGHT", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    rightPanel:SetPoint("LEFT", leftPanel, "RIGHT", 10, 0)
    rightPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = {left=3, right=3, top=3, bottom=3}
    })
    rightPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    rightPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    UI.frame = frame
    UI.leftPanel = leftPanel
    UI.rightPanel = rightPanel

    UI.BuildGallery(leftPanel)
    UI.BuildDetailPane(rightPanel)
end

function UI.BuildGallery(parent)
    local uploadBtn = CreateFrame("Button", nil, parent)
    uploadBtn:SetPoint("BOTTOM", 0, 10)
    uploadBtn:SetSize(200, 24)
    local uploadText = uploadBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    uploadText:SetText("Upload your Blueprint")
    uploadText:SetPoint("CENTER")
    uploadText:SetTextColor(0.6, 0.6, 0.6)
    uploadBtn:SetScript("OnEnter", function() uploadText:SetTextColor(1, 0.82, 0) end)
    uploadBtn:SetScript("OnLeave", function() uploadText:SetTextColor(0.6, 0.6, 0.6) end)
    uploadBtn:SetScript("OnClick", function() if HB_UploadFrame then HB_UploadFrame:Show() end end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 40)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(220, 1)
    scrollFrame:SetScrollChild(scrollChild)

    UI.galleryScrollChild = scrollChild
    UI.galleryCards = {}

    local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("TOP", 0, -30)
    emptyText:SetText("No blueprints match your filter.")
    emptyText:SetTextColor(0.6, 0.6, 0.6)
    emptyText:Hide()
    UI.galleryEmptyText = emptyText
end

local function FormatScoreText(bp)
    local cache = Blueprints.ContentCache[bp.code]

    if not cache then
        return "|cff888888Select to check|r"
    elseif cache.state == "pending" then
        return "|cff888888Checking...|r"
    elseif cache.state == "failed" then
        return "|cffff5050Couldn't fetch contents|r"
    end

    local pct = Blueprints.GetScore(bp)
    if pct == nil then
        return "|cff888888Unknown|r"
    elseif pct >= 1 then
        return "|cff20ff20Buildable (100%)|r"
    elseif pct >= 0.8 then
        return string.format("|cff40ff40Buildable (%d%%)|r", math.floor(pct * 100))
    else
        return string.format("|cffff5050Buildable (%d%%)|r", math.floor(pct * 100))
    end
end

function Blueprints.UpdateGallery()
    Blueprints.Library = _G["HomeBoundBlueprintsDB"] or {}
    
    if not UI.galleryCards then return end

    for _, card in ipairs(UI.galleryCards) do card:Hide() end
    UI.galleryEmptyText:Hide()

    local filtered = {}
    local filters = hb_settings.tabFilters["blueprints"] or {}
    local search = db.currentSearchQuery or ""
    local fType = filters.bpType or "all"
    local fSort = filters.sort or "newest"

    for _, bp in ipairs(Blueprints.Library) do
        local matchType = (fType == "all") or (bp.type and bp.type:lower() == fType)
        local matchSearch = true
        if search ~= "" then
            local textToSearch = string.lower((bp.title or "") .. " " .. (bp.author or "") .. " " .. (bp.description or ""))
            if not string.find(textToSearch, search, 1, true) then
                matchSearch = false
            end
        end

        if matchType and matchSearch then
            table.insert(filtered, bp)
        end
    end

    table.sort(filtered, function(a, b)
        local pctA = select(1, Blueprints.GetScore(a))
        local pctB = select(1, Blueprints.GetScore(b))
        
        local isUnknownA = (pctA == nil)
        local isUnknownB = (pctB == nil)
        
        if isUnknownA ~= isUnknownB then
            return isUnknownB
        end

        if fSort == "newest" then
            return (a.addedIn or 0) > (b.addedIn or 0)
        elseif fSort == "oldest" then
            return (a.addedIn or 0) < (b.addedIn or 0)
        elseif fSort == "buildable_high" then
            if pctA == pctB then
                return (a.addedIn or 0) > (b.addedIn or 0)
            end
            return (pctA or 0) > (pctB or 0)
        elseif fSort == "buildable_low" then
            if pctA == pctB then
                return (a.addedIn or 0) > (b.addedIn or 0)
            end
            return (pctA or 0) < (pctB or 0)
        end
        return false
    end)

    if #filtered == 0 then
        UI.galleryEmptyText:Show()
        UI.galleryScrollChild:SetHeight(100)
        if UI.ShowEmptyDetail then UI.ShowEmptyDetail() end
        return
    end

    local y = 0
    local spacing = 8
    local cardHeight = 72

    for i, bp in ipairs(filtered) do
        local card = UI.galleryCards[i]
        if not card then
            card = CreateFrame("Button", nil, UI.galleryScrollChild, "BackdropTemplate")
            card:SetSize(224, cardHeight)
            ApplyBackdrop(card, 0.12, 0.12, 0.12, 0.95)

            card.thumb = card:CreateTexture(nil, "ARTWORK")
            card.thumb:SetSize(56, 56)
            card.thumb:SetPoint("LEFT", 8, 0)
            card.thumb:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            card.title:SetPoint("TOPLEFT", card.thumb, "TOPRIGHT", 8, -4)
            card.title:SetPoint("RIGHT", -8, 0)
            card.title:SetJustifyH("LEFT")
            card.title:SetTextColor(1, 0.82, 0)
            card.title:SetWordWrap(false)

            card.author = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            card.author:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
            card.author:SetTextColor(0.7, 0.7, 0.7)

            card.score = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            card.score:SetPoint("BOTTOMLEFT", card.thumb, "BOTTOMRIGHT", 8, 4)

            card:SetScript("OnEnter", function(self)
                if UI.selectedBP ~= self.bp then
                    self:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
                end
            end)
            card:SetScript("OnLeave", function(self)
                if UI.selectedBP ~= self.bp then
                    self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                end
            end)
            card:SetScript("OnClick", function(self)
                for _, c in ipairs(UI.galleryCards) do c:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) end
                self:SetBackdropBorderColor(1, 0.82, 0, 1)
                UI.selectedBP = self.bp
                UI.ShowDetail(self.bp)
            end)

            UI.galleryCards[i] = card
        end

        card.bp = bp
        card.title:SetText(bp.title)
        card.author:SetText("by " .. bp.author)
        if bp.thumb then
            card.thumb:SetTexture(bp.thumb)
        end

        if UI.selectedBP == bp then
            card:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            card:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end

        card.score:SetText(FormatScoreText(bp))

        card:SetPoint("TOPLEFT", 0, -y)
        card:Show()
        y = y + cardHeight + spacing
    end

    UI.galleryScrollChild:SetHeight(y)

    local foundSelected = false
    if UI.selectedBP then
        for _, bp in ipairs(filtered) do
            if bp == UI.selectedBP then foundSelected = true; break end
        end
    end

    if not foundSelected then
        UI.galleryCards[1]:Click()
    else
        UI.ShowDetail(UI.selectedBP)
    end
end

function UI.BuildDetailPane(parent)
    UI.detailContent = CreateFrame("Frame", nil, parent)
    UI.detailContent:SetAllPoints()

    local hero = UI.detailContent:CreateTexture(nil, "ARTWORK")
    hero:SetPoint("TOPLEFT", 8, -8)
    hero:SetPoint("TOPRIGHT", -8, -8)
    hero:SetSize(340, 191)
    --hero:SetTexCoord(0, 1, 0.1, 0.9)
    UI.detailHero = hero
    
    local heroBtn = CreateFrame("Button", nil, UI.detailContent)
    heroBtn:SetAllPoints(hero)
    UI.heroBtn = heroBtn

    local heroPrev = CreateFrame("Button", nil, UI.detailContent)
    heroPrev:SetSize(32, 32)
    heroPrev:SetPoint("LEFT", hero, "LEFT", 4, 0)
    heroPrev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    heroPrev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    heroPrev:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    heroPrev:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    heroPrev:SetFrameLevel(heroBtn:GetFrameLevel() + 1)
    UI.heroPrev = heroPrev

    local heroNext = CreateFrame("Button", nil, UI.detailContent)
    heroNext:SetSize(32, 32)
    heroNext:SetPoint("RIGHT", hero, "RIGHT", -4, 0)
    heroNext:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    heroNext:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    heroNext:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    heroNext:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    heroNext:SetFrameLevel(heroBtn:GetFrameLevel() + 1)
    UI.heroNext = heroNext

    local fsFrame = CreateFrame("Frame", "HB_BlueprintFullscreenFrame", UIParent)
    fsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    fsFrame:SetAllPoints()
    fsFrame:EnableMouse(true)
    fsFrame:Hide()
    
    fsFrame:EnableKeyboard(true)
    fsFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    fsFrame:SetScript("OnMouseDown", function() fsFrame:Hide() end)

    local fsBg = fsFrame:CreateTexture(nil, "BACKGROUND")
    fsBg:SetAllPoints()
    fsBg:SetColorTexture(0, 0, 0, 0.9)

    local fsImg = fsFrame:CreateTexture(nil, "ARTWORK")
    fsImg:SetPoint("CENTER")
    fsImg:SetSize(960, 540) --16:9
    fsImg:SetTexCoord(0, 1, 0, 1)

    local fsImgBlocker = CreateFrame("Button", nil, fsFrame)
    fsImgBlocker:SetAllPoints(fsImg)
    fsImgBlocker:SetScript("OnClick", function() end)

    local fsCloseTip = fsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsCloseTip:SetPoint("BOTTOM", 0, 60)
    fsCloseTip:SetText("Press ESC or click anywhere outside the image to close")
    fsCloseTip:SetTextColor(0.7, 0.7, 0.7)

    local fsPrev = CreateFrame("Button", nil, fsFrame)
    fsPrev:SetSize(32, 32)
    fsPrev:SetPoint("RIGHT", fsImg, "LEFT", -20, 0)
    fsPrev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    fsPrev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    fsPrev:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local fsNext = CreateFrame("Button", nil, fsFrame)
    fsNext:SetSize(32, 32)
    fsNext:SetPoint("LEFT", fsImg, "RIGHT", 20, 0)
    fsNext:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    fsNext:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    fsNext:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    UI.fsFrame = fsFrame
    UI.fsImg = fsImg

    function UI.UpdateFullscreenHero()
        local bp = UI.selectedBP
        if not bp then return end
        local screenshots = bp.screenshots or {}
        if screenshots[fsFrame.imgIndex] then
            fsImg:SetTexture(screenshots[fsFrame.imgIndex])
        end
        if #screenshots > 1 then
            fsPrev:Show()
            fsNext:Show()
        else
            fsPrev:Hide()
            fsNext:Hide()
        end
    end

    fsPrev:SetScript("OnClick", function()
        local screenshots = UI.selectedBP and UI.selectedBP.screenshots or {}
        fsFrame.imgIndex = fsFrame.imgIndex - 1
        if fsFrame.imgIndex < 1 then fsFrame.imgIndex = math.max(1, #screenshots) end
        UI.UpdateFullscreenHero()
    end)
    fsNext:SetScript("OnClick", function()
        local screenshots = UI.selectedBP and UI.selectedBP.screenshots or {}
        fsFrame.imgIndex = fsFrame.imgIndex + 1
        if fsFrame.imgIndex > #screenshots then fsFrame.imgIndex = 1 end
        UI.UpdateFullscreenHero()
    end)

    heroBtn:SetScript("OnClick", function()
        local bp = UI.selectedBP
        if not bp or not bp.screenshots or #bp.screenshots == 0 then return end
        UI.fsFrame.imgIndex = UI.detailHero.imgIndex or 1
        UI.UpdateFullscreenHero()
        UI.fsFrame:Show()
    end)

    function UI.UpdateHero()
        local bp = UI.selectedBP
        if not bp then return end
        local screenshots = bp.screenshots or {}

        if screenshots[UI.detailHero.imgIndex] then
            UI.detailHero:SetTexture(screenshots[UI.detailHero.imgIndex])
            if not UI.itemsExpanded then
                UI.detailHero:Show()
            end
        else
            UI.detailHero:Hide()
        end

        if #screenshots > 1 and not UI.itemsExpanded then
            UI.heroPrev:Show()
            UI.heroNext:Show()
        else
            UI.heroPrev:Hide()
            UI.heroNext:Hide()
        end
    end

    heroPrev:SetScript("OnClick", function()
        if not UI.selectedBP then return end
        local screenshots = UI.selectedBP.screenshots or {}
        UI.detailHero.imgIndex = UI.detailHero.imgIndex - 1
        if UI.detailHero.imgIndex < 1 then UI.detailHero.imgIndex = math.max(1, #screenshots) end
        UI.UpdateHero()
    end)
    heroNext:SetScript("OnClick", function()
        if not UI.selectedBP then return end
        local screenshots = UI.selectedBP.screenshots or {}
        UI.detailHero.imgIndex = UI.detailHero.imgIndex + 1
        if UI.detailHero.imgIndex > #screenshots then UI.detailHero.imgIndex = 1 end
        UI.UpdateHero()
    end)

    local title = UI.detailContent:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    title:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 4, -8)
    title:SetPoint("RIGHT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.85, 0)
    UI.detailTitle = title

    local author = UI.detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    author:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    author:SetTextColor(0.8, 0.8, 0.8)
    UI.detailAuthor = author

    local score = UI.detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    score:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -8)
    UI.detailScore = score

    local flagsText = UI.detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    flagsText:SetPoint("TOPLEFT", score, "BOTTOMLEFT", 0, -8)
    flagsText:SetPoint("RIGHT", -8, 0)
    flagsText:SetJustifyH("LEFT")
    flagsText:SetJustifyV("TOP")
    flagsText:SetWordWrap(true)
    flagsText:SetSpacing(2)
    flagsText:SetTextColor(1, 0.5, 0.3)
    UI.detailFlags = flagsText

    local desc = UI.detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", flagsText, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", -12, 0)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetHeight(26)
    desc:SetWordWrap(true)
    UI.detailDesc = desc

    local codeLabel = UI.detailContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    codeLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    codeLabel:SetText("Share Code (Ctrl+C):")
    codeLabel:SetTextColor(1, 0.82, 0)

    local importBtn = CreateFrame("Button", nil, UI.detailContent, "SharedButtonSmallTemplate")
    importBtn:SetSize(80, 22)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        if not UI.selectedBP then return end
        local code = UI.selectedBP.code

        if C_HousingBlueprint and C_HousingBlueprint.IsShareCodeValid and not C_HousingBlueprint.IsShareCodeValid(code) then
            print("|cffffd100Home Bound:|r This share code is no longer valid.")
            return
        end

        local bpType = C_HousingBlueprint and C_HousingBlueprint.GetBlueprintTypeForCode
            and C_HousingBlueprint.GetBlueprintTypeForCode(code)

        if bpType and C_HousingBlueprint.CanImportTypeFromCurrentLocation then
            local ok, locationValid = pcall(C_HousingBlueprint.CanImportTypeFromCurrentLocation, bpType)
            if ok and locationValid == false then
                print("|cffffd100Home Bound:|r You can't import this type of blueprint from your current location.")
                return
            end
        end

        local cache = Blueprints.ContentCache[code]
        if cache and cache.state == "ready" and cache.blockingRequirementFlags and cache.blockingRequirementFlags ~= 0 then
            local reason = Blueprints.GetFirstUnmetFlag(cache.blockingRequirementFlags)
            print("|cffffd100Home Bound:|r Can't import - " .. (reason or "a requirement isn't met") .. ".")
            return
        end

        local isRoom = false
        if Enum and Enum.HousingBlueprintType and bpType == Enum.HousingBlueprintType.Room then
            isRoom = true
        elseif type(bpType) == "string" and bpType:lower() == "room" then
            isRoom = true
        elseif UI.selectedBP.type and UI.selectedBP.type:lower() == "room" then
            isRoom = true
        end

        if isRoom and C_HousingBlueprint and C_HousingBlueprint.StartImportRoomBlueprint then
            C_HousingBlueprint.StartImportRoomBlueprint(code)
            print("|cffffd100Home Bound:|r Importing room " .. UI.selectedBP.title .. "...")
        elseif C_HousingBlueprint and C_HousingBlueprint.ImportBlueprint then
            C_HousingBlueprint.ImportBlueprint(code)
            print("|cffffd100Home Bound:|r Importing " .. UI.selectedBP.title .. "...")
        else
            print("|cffffd100Home Bound:|r Import API not available.")
        end
    end)
    UI.importBtn = importBtn

    local codeBox = CreateFrame("EditBox", nil, UI.detailContent, "InputBoxTemplate")
    codeBox:SetHeight(20)
    codeBox:SetPoint("TOPLEFT", codeLabel, "BOTTOMLEFT", 4, -4)
    codeBox:SetPoint("RIGHT", desc, "RIGHT", -90, 0)
    codeBox:SetAutoFocus(false)
    codeBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    UI.codeBox = codeBox

    importBtn:SetPoint("LEFT", codeBox, "RIGHT", 10, 0)

    function UI.RefreshImportButton(bp)
        if not UI.importBtn then return end
        bp = bp or UI.selectedBP

        local available = true
        local reason = nil

        if C_HousingBlueprint and C_HousingBlueprint.GetImportAvailability then
            local ok, availability = pcall(C_HousingBlueprint.GetImportAvailability)
            if ok and availability == false then
                available = false
                reason = "Importing isn't available right now."
            end
        end

        if available and bp then
            local cache = Blueprints.ContentCache[bp.code]
            if cache and cache.state == "ready" and cache.blockingRequirementFlags and cache.blockingRequirementFlags ~= 0 then
                available = false
                local firstReason = Blueprints.GetFirstUnmetFlag(cache.blockingRequirementFlags)
                reason = "Can't import: " .. (firstReason or "requirement not met")
            end
        end

        UI.importBtn:SetEnabled(available)
        UI.importBtn.disabledReason = reason
    end

    local manifestLabel = UI.detailContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manifestLabel:SetText("Items:")
    manifestLabel:SetTextColor(1, 0.82, 0)
    UI.manifestLabel = manifestLabel

    local manifestStatus = UI.detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    manifestStatus:SetPoint("LEFT", manifestLabel, "RIGHT", 8, 0)
    manifestStatus:SetTextColor(0.6, 0.6, 0.6)
    UI.manifestStatus = manifestStatus

    local expandBtn = CreateFrame("Button", nil, UI.detailContent, "SharedButtonSmallTemplate")
    expandBtn:SetSize(92, 22)
    expandBtn:SetPoint("LEFT", manifestStatus, "RIGHT", 10, 0)
    expandBtn:SetText("Open list")
    UI.expandBtn = expandBtn

    local verifyBtn = CreateFrame("Button", nil, UI.detailContent, "SharedButtonSmallTemplate")
    verifyBtn:SetSize(80, 22)
    verifyBtn:SetPoint("LEFT", expandBtn, "RIGHT", 10, 0)
    verifyBtn:SetText("Verify")
    verifyBtn:SetScript("OnClick", function()
        if UI.selectedBP and UI.selectedBP.code then
            Blueprints.RequestContents(UI.selectedBP.code, true)
            UI.ShowDetail(UI.selectedBP)
        end
    end)
    UI.verifyBtn = verifyBtn

    UI.collapsibleWidgets = {
        hero, heroBtn, heroPrev, heroNext, title, author, score,
        flagsText, desc, codeLabel, codeBox, importBtn,
    }

    function UI.SetItemsExpanded(expanded)
        UI.itemsExpanded = expanded
        for _, w in ipairs(UI.collapsibleWidgets) do
            if expanded then w:Hide() else w:Show() end
        end

        manifestLabel:ClearAllPoints()
        if expanded then
            manifestLabel:SetPoint("TOPLEFT", UI.detailContent, "TOPLEFT", 12, -14)
            expandBtn:SetText("Close list")
        else
            manifestLabel:SetPoint("TOPLEFT", codeBox, "BOTTOMLEFT", -4, -10)
            expandBtn:SetText("Open list")
        end

        if not expanded then
            UI.UpdateHero()
        end

        UI.RefreshManifest()
    end

    expandBtn:SetScript("OnClick", function()
        UI.SetItemsExpanded(not UI.itemsExpanded)
    end)

    manifestLabel:SetPoint("TOPLEFT", codeBox, "BOTTOMLEFT", -4, -10)

    local scrollFrame = CreateFrame("ScrollFrame", nil, UI.detailContent, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", manifestLabel, "BOTTOMLEFT", -4, -20)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    scrollFrame:Hide()

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(310)
    scrollFrame:SetScrollChild(scrollChild)

    UI.manifestScrollFrame = scrollFrame
    UI.manifestScrollChild = scrollChild
    UI.manifestLines = {}
    UI.manifestHeaders = {}

    local emptyDisplay = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    emptyDisplay:SetPoint("CENTER", 0, 0)
    emptyDisplay:SetText("Select a blueprint")
    emptyDisplay:SetTextColor(0.5, 0.5, 0.5)
    emptyDisplay:Hide()
    UI.detailEmptyText = emptyDisplay

    UI.RefreshImportButton()
end

function UI.ShowEmptyDetail()
    if UI.detailContent then UI.detailContent:Hide() end
    if UI.detailEmptyText then UI.detailEmptyText:Show() end
end

function UI.RefreshManifest()
    if not UI.manifestScrollFrame then return end

    if not UI.itemsExpanded then
        UI.manifestScrollFrame:Hide()
        return
    end
    UI.manifestScrollFrame:Show()

    for _, line in ipairs(UI.manifestLines) do line:Hide() end
    for _, header in ipairs(UI.manifestHeaders) do header:Hide() end

    local bp = UI.selectedBP
    local cache = bp and Blueprints.ContentCache[bp.code]
    if not cache or cache.state ~= "ready" then
        UI.manifestScrollChild:SetHeight(1)
        return
    end

    local groups, groupOrder = {}, {}
    for _, entry in ipairs(cache.entries) do
        local gKey = entry.groupIndex or 0
        if not groups[gKey] then
            groups[gKey] = { contentType = entry.contentType, list = {} }
            table.insert(groupOrder, gKey)
        end
        table.insert(groups[gKey].list, entry)
    end
    table.sort(groupOrder)

    local y = 4
    local lineIndex, headerIndex = 0, 0
    local showHeaders = #groupOrder > 1

    for _, gKey in ipairs(groupOrder) do
        local group = groups[gKey]

        if showHeaders then
            if y > 4 then y = y + 10 end
            
            headerIndex = headerIndex + 1
            local header = UI.manifestHeaders[headerIndex]
            if not header then
                header = UI.manifestScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                header:SetJustifyH("LEFT")
                header:SetTextColor(1, 0.82, 0)
                UI.manifestHeaders[headerIndex] = header
            end

            local reqSum, ownSum = 0, 0
            for _, e in ipairs(group.list) do
                if not e.invalid then
                    local req = e.total or 0
                    reqSum = reqSum + req
                    ownSum = ownSum + math.min(e.owned or 0, req)
                end
            end

            header:SetText(string.format("%s: %d/%d", Blueprints.ContentTypeLabel[group.contentType] or "Other", ownSum, reqSum))
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 10, -y)
            header:Show()
            y = y + 16
        end

        for _, entry in ipairs(group.list) do
            lineIndex = lineIndex + 1
            local line = UI.manifestLines[lineIndex]
            if not line then
                line = CreateFrame("Button", nil, UI.manifestScrollChild)
                line:SetHeight(20)
                line:RegisterForClicks("AnyUp")

                line.qtyText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                line.qtyText:SetPoint("LEFT", 10, 0)
                line.qtyText:SetWidth(45)
                line.qtyText:SetJustifyH("RIGHT")

                line.nameText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                line.nameText:SetPoint("LEFT", line.qtyText, "RIGHT", 8, 0)
                line.nameText:SetPoint("RIGHT", -10, 0)
                line.nameText:SetJustifyH("LEFT")
                line.nameText:SetWordWrap(false)

                line:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if not Blueprints.TryShowCatalogTooltip(self.entryContentType, self.entryRecordID) then
                        GameTooltip:SetText(self.entryName or "")
                        if self.entryTooltip then
                            GameTooltip:AddLine(self.entryTooltip, 1, 1, 1, true)
                        end
                    end
                    GameTooltip:Show()
                end)
                line:SetScript("OnLeave", GameTooltip_Hide)
                
                line:SetScript("OnClick", function(self, button)
                    local link, itemID
                    if self.entryContentType == Enum.HousingBlueprintContentType.Dye then
                        itemID = self.entryRecordID
                    else
                        local entryType = ContentTypeToCatalogEntryType[self.entryContentType]
                        if entryType and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID then
                            local info = C_HousingCatalog.GetCatalogEntryInfoByRecordID(entryType, self.entryRecordID)
                            if info and info.itemID then
                                itemID = info.itemID
                            end
                        end
                    end

                    if itemID then
                        local _, itemLink = GetItemInfo(itemID)
                        link = itemLink or ("\124cffa335ee\124Hitem:" .. itemID .. "::::::::::::\124h[Item " .. itemID .. "]\124h\124r")
                    end

                    if IsShiftKeyDown() and link then
                        if ChatEdit_InsertLink then
                            ChatEdit_InsertLink(link)
                        end
                    elseif IsControlKeyDown() and itemID and self.entryContentType == Enum.HousingBlueprintContentType.Decor then
                        if DressUpItemLink and link then
                            DressUpItemLink(link)
                        end
                    end
                end)

                UI.manifestLines[lineIndex] = line
            end

            local required = entry.total or 0
            local owned = entry.owned or 0
            local isComplete = owned >= required

            line.entryName = entry.name
            line.entryTooltip = entry.tooltip
            line.entryContentType = entry.contentType
            line.entryRecordID = entry.recordID

            line.qtyText:SetText(string.format("%d/%d", owned, required))
            if entry.invalid then
                line.qtyText:SetTextColor(0.5, 0.5, 0.5)
                line.nameText:SetTextColor(0.5, 0.5, 0.5)
            elseif isComplete then
                line.qtyText:SetTextColor(0.2, 1, 0.2)
                line.nameText:SetTextColor(0.6, 0.6, 0.6)
            else
                line.qtyText:SetTextColor(1, 0.2, 0.2)
                line.nameText:SetTextColor(0.9, 0.9, 0.9)
            end

            local suffix = ""--entry.contentType == Enum.HousingBlueprintContentType.Dye and "  |cff8c661aDye|r" or ""
            if entry.invalid then
                suffix = suffix .. "  |cffff4040(Unusable)|r"
            end
            line.nameText:SetText(entry.name .. suffix)

            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", 0, -y)
            line:SetPoint("RIGHT", 0, -y)
            line:Show()
            y = y + 20
        end
    end

    UI.manifestScrollChild:SetHeight(y + 10)
end

function UI.ShowDetail(bp)
    if not UI.detailContent then return end
    UI.detailEmptyText:Hide()
    UI.detailContent:Show()

    UI.detailHero.imgIndex = 1
    UI.UpdateHero()

    UI.detailTitle:SetText(bp.title)

    local liveType = bp.type
    if C_HousingBlueprint and C_HousingBlueprint.GetBlueprintTypeForCode then
        local ok, t = pcall(C_HousingBlueprint.GetBlueprintTypeForCode, bp.code)
        if ok and t then liveType = t end
    end
    local typeLabel = type(liveType) == "string"
        and (liveType:sub(1,1):upper() .. liveType:sub(2))
        or (bp.type and (bp.type:sub(1,1):upper() .. bp.type:sub(2)) or "Blueprint")

    UI.detailAuthor:SetText("by " .. bp.author .. "  |  " .. typeLabel)
    UI.detailDesc:SetText(bp.description)
    UI.codeBox:SetText(bp.code)
    UI.codeBox:SetCursorPosition(0)

    local cache = Blueprints.RequestContents(bp.code)
    local pct, owned, req = Blueprints.GetScore(bp)

    if not cache or cache.state == "pending" then
        UI.detailScore:SetText("|cff888888Checking live blueprint contents...|r")
        UI.manifestStatus:SetText("")
        UI.detailFlags:SetText("")
    elseif cache.state == "failed" then
        UI.detailScore:SetText("|cffff5050Couldn't fetch this blueprint's contents.|r")
        UI.manifestStatus:SetText(cache.error and tostring(cache.error) or "")
        UI.detailFlags:SetText("")
    else
        if pct and pct >= 1 then
            UI.detailScore:SetText(string.format("|cff20ff20Buildable: You own all %d required items!|r", req))
        else
            UI.detailScore:SetText(string.format("|cffff5050Buildable: %d%% (%d/%d items owned)|r", math.floor((pct or 0) * 100), owned, req))
        end
        UI.manifestStatus:SetText("")

        local errorLine = Blueprints.FormatUnmetLine(cache.unmetRequirementFlags)
        UI.detailFlags:SetText(errorLine and ("|cffff8040" .. errorLine .. "|r") or "")
    end

    UI.RefreshImportButton(bp)
    UI.SetItemsExpanded(UI.itemsExpanded or false)
end