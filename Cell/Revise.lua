local addonName, Cell = ...
local L = Cell.L
local F = Cell.funcs
local I = Cell.iFuncs
local U = Cell.uFuncs

function F.Revise()
    local dbRevision = CellDB["revise"] and tonumber(string.match(CellDB["revise"], "%d+")) or 0
    F.Debug("DBRevision:", dbRevision)

    local charaDbRevision
    if CellCharacterDB then
        charaDbRevision = CellCharacterDB["revise"] and tonumber(string.match(CellCharacterDB["revise"], "%d+")) or 0
        F.Debug("CharaDBRevision:", charaDbRevision)
    end

    if CellDB["revise"] and dbRevision < Cell.MIN_VERSION then -- update from an unsupported version
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function()
            f:UnregisterAllEvents()
            local popup = Cell.CreateConfirmPopup(CellAnchorFrame, 260, L["RESET"].."\n"..L["RESET_YES_NO"], function()
                CellDB = nil
                CellCharacterDB = nil
                ReloadUI()
            end)
            popup:SetPoint("TOPLEFT")
        end)
        return
    end

    if CellCharacterDB and CellCharacterDB["revise"] and charaDbRevision < Cell.MIN_VERSION then -- update from an unsupported version
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function()
            f:UnregisterAllEvents()
            local popup = Cell.CreateConfirmPopup(CellAnchorFrame, 260, L["RESET_CHARACTER"].."\n|cFFB7B7B7"..L["RESET_INCLUDES"].."|r\n"..L["RESET_YES_NO"], function()
                CellCharacterDB = nil
                ReloadUI()
            end)
            popup:SetPoint("TOPLEFT")
        end)
        return
    end

    -- r247-release
    if CellDB["revise"] and dbRevision < 247 then
        CellDB["appearance"]["scale"] = 1
    end

    -- r250-release
    if CellDB["revise"] and dbRevision < 250 then
        for _, layout in pairs(CellDB["layouts"]) do
            for _, i in pairs(layout["indicators"]) do
                if i.type == "icons" then -- fix Healers
                    if not i.glowOptions then
                        i.glowOptions = {"None", {0.95, 0.95, 0.32, 1}}
                    end
                end
            end
        end
    end

    -- 254-release
    if CellDB["revise"] and dbRevision < 254 then
        if Cell.isMists then
            for _, layout in pairs(CellDB["layouts"]) do
                for _, i in pairs(layout["indicators"]) do
                    if i.indicatorName == "powerText" then
                        -- reset powerText filter
                        i.filters = F.Copy(Cell.defaults.layout.indicators[Cell.defaults.indicatorIndices.powerText].filters)
                    end
                end

                -- reset power filters
                layout["powerFilters"] = F.Copy(Cell.defaults.layout.powerFilters)
            end

            -- enable healAbsorb
            CellDB["appearance"]["healAbsorb"][1] = true

            if not next(CellDB["actions"]) then
                CellDB["actions"] = I.GetDefaultActions()
            end
        end
    end

    -- r262-release
    if CellDB["revise"] and dbRevision < 262 then
        CellDB["general"]["alwaysUpdateAuras"] = false

        if type(CellDB["general"]["hideBlizzardRaidManager"]) ~= "boolean" then
            CellDB["general"]["hideBlizzardRaidManager"] = true
        end

        for _, layout in pairs(CellDB["layouts"]) do
            for _, i in pairs(layout["indicators"]) do
                if i.auraType == "debuff" and not i.castBy then
                    i.castBy = "anyone"
                end
            end
        end
    end

    -- r264-release
    if CellDB["revise"] and dbRevision < 264 then
        if Cell.isRetail then
            F.TInsertIfNotExists(CellDB["targetedSpellsList"], unpack(I.GetDefaultTargetedSpellsList()))
        end

        CellDB["tools"]["buffTracker"][5] = U.GetBuffTrackerDefaults()
    end

    -- 269-release
    if CellDB["revise"] and dbRevision < 269 then
        if Cell.isMists and GetCVar("portal") == "CN" then
            for _, layout in pairs(CellDB["layouts"]) do
                for _, i in pairs(layout["indicators"]) do
                    if i.indicatorName == "powerText" then
                        -- reset powerText filter
                        i.filters = F.Copy(Cell.defaults.layout.indicators[Cell.defaults.indicatorIndices.powerText].filters)
                    end
                end

                -- reset power filters
                layout["powerFilters"] = F.Copy(Cell.defaults.layout.powerFilters)
            end

            -- enable healAbsorb
            CellDB["appearance"]["healAbsorb"][1] = true

            if not next(CellDB["actions"]) then
                CellDB["actions"] = I.GetDefaultActions()
            end
        end
    end

    -- Migration for Cell r275 (Midnight 12.0.0 compatibility)
    if not CellDB["revise"] or dbRevision < 275 then
        -- Remove useCleuHealthUpdater setting (CLEU-based health updater removed in 12.0.0)
        if CellDB["general"] then
            CellDB["general"]["useCleuHealthUpdater"] = nil
        end
        -- Migrate "Flash" bar animation to "Smooth" (Flash removed in 12.0.0)
        if CellDB["appearance"] and CellDB["appearance"]["barAnimation"] == "Flash" then
            CellDB["appearance"]["barAnimation"] = "Smooth"
        end
        -- Note: profile import compatibility warning added elsewhere.
        -- Saved variable secrets: any secrets stored before this version will be nil'd by WoW.
    end

    -- ----------------------------------------------------------------------- --
    --            update from old versions, validate all indicators            --
    -- ----------------------------------------------------------------------- --
    if CellDB["revise"] and CellDB["revise"] ~=  Cell.version then
        for layoutName, layout in pairs(CellDB["layouts"]) do
            local toValidate = F.Copy(Cell.defaults.indicatorIndices)
            local temp = {}

            -- built-ins
            for i, t in ipairs(layout["indicators"]) do
                local name = t["indicatorName"]
                local correctIndex = toValidate[name]

                if t["type"] == "built-in" and correctIndex then
                    F.Debug(layoutName, "CORRECT_FOUND", correctIndex, name)
                    temp[correctIndex] = t
                    -- remove validated
                    toValidate[name] = nil
                end
            end

            -- fix missing indicators
            for name, index in pairs(toValidate) do
                F.Debug(layoutName, "FIXED_MISSING", index, name)
                temp[index] = F.Copy(Cell.defaults.layout.indicators[index])
            end

            --? check again
            local maxKey = 0
            for i in pairs(temp) do
                maxKey = max(maxKey, i)
            end
            for i = 1, maxKey do
                if i <= Cell.defaults.builtIns then
                    if not temp[i] or i ~= Cell.defaults.indicatorIndices[temp[i]["indicatorName"]] then
                        F.Debug(layoutName, "RESET_WRONG", i, temp[i] and temp[i]["indicatorName"])
                        temp[i] = F.Copy(Cell.defaults.layout.indicators[i])
                    end
                else
                    temp[i] = nil
                end
            end

            -- customs
            for i, t in pairs(layout["indicators"]) do
                if t["type"] ~= "built-in" then
                    tinsert(temp, t)
                end
            end

            layout["indicators"] = temp
        end
    end

    --! update custom indicator names
    for _, layout in pairs(CellDB["layouts"]) do
        local index = 1
        for i, t in ipairs(layout["indicators"]) do
            if t["type"] ~= "built-in" then
                t["indicatorName"] = "indicator"..index
                index = index + 1
            end
        end
    end

    for _, layout in pairs(CellDB["layouts"]) do
        for _, t in pairs(layout["indicators"] or {}) do
            if t["indicatorName"] == "debuffs" and type(t["size"]) == "table" and type(t["size"][1]) == "table" then
                t["size"] = {t["size"][1][1], t["size"][1][2]}
                t["bigDebuffs"] = nil
                t["enableBlacklistShortcut"] = nil
            end
        end
    end

    if not CellDB["miliuiDurationThresholdOnce"] then
        CellDB["miliuiDurationThresholdOnce"] = true
        --! ⚠ and skip the conversion entirely for a database that has already logged in on
        --! this build: the old ungated loop converted it long ago, so the only thing a run
        --! now could do is undo an "always" the player has since chosen on purpose.
        if CellDB["revise"] ~= Cell.version then
            for _, layout in pairs(CellDB["layouts"]) do
                for _, t in pairs(layout["indicators"] or {}) do
                    local name = t["indicatorName"]
                    local isCustomIcon = t["type"] == "icons" or t["type"] == "icon"
                    if t["showDuration"] == true and (name == "debuffs" or name == "raidDebuffs"
                        or name == "externalCooldowns" or name == "defensiveCooldowns"
                        or (isCustomIcon and t["auraType"] == "buff")) then
                        t["showDuration"] = 60
                    end
                end
            end
        end
    end

    if not(CellDB["revise"]) or dbRevision < 281 then
        for _, layout in pairs(CellDB["layouts"]) do
            for _, t in pairs(layout["indicators"] or {}) do
                local name = t["indicatorName"]
                if name == "raidDebuffs" then
                    t["name"] = "Important Debuffs"
                    t["filters"] = t["filters"] or {
                        ["bossRole"] = true,
                        ["priority"] = true,
                        ["crowdControl"] = true,
                        ["raid"] = true,
                        ["dispellable"] = true,
                    }
                    t["size"] = {18, 18}
                    if t["font"] and t["font"][1] then t["font"][1][2] = 9 end

                elseif name == "debuffs" then
                    t["size"] = {15, 15}
                    if t["font"] and t["font"][1] then t["font"][1][2] = 8 end

                elseif name == "dispels" then
                    t["filters"] = t["filters"] or {}
                    t["filters"]["dispellableByMe"] = true

                elseif t["name"] == "Healers" and t["auraType"] == "buff"
                    and (t["type"] == "icons" or t["type"] == "icon") then
                    t["size"] = {17, 17}
                    if t["font"] then
                        if t["font"][1] then t["font"][1][2] = 8 end
                        if t["font"][2] then t["font"][2][2] = 11 end
                    end
                end
            end
        end
    end

    if not(CellDB["revise"]) or dbRevision < 282 then
        for _, layout in pairs(CellDB["layouts"]) do
            for _, t in pairs(layout["indicators"] or {}) do
                if t["indicatorName"] == "debuffs" then
                    t["excludeImportant"] = true
                    t["excludeDispellable"] = nil -- superseded before it ever shipped
                end
            end
        end
    end

    if not(CellDB["revise"]) or dbRevision < 287 then
        if type(CellDB["actions"]) == "table" then
            local retired = {
                [431416] = 1234768, -- Algari Healing Potion -> Silvermoon Health Potion
                [431932] = 1236616, -- Tempered Potion       -> Light's Potential
            }
            local seen = {}
            for _, t in pairs(CellDB["actions"]) do
                if type(t) == "table" then seen[t[1]] = true end
            end
            for _, t in pairs(CellDB["actions"]) do
                if type(t) == "table" and retired[t[1]] and not seen[retired[t[1]]] then
                    t[1] = retired[t[1]]
                end
            end
            Cell.vars.actions = I.ConvertActions(CellDB["actions"])
        end
    end

    if not(CellDB["revise"]) or dbRevision < 287 then
        if type(CellDB["offensives"]) ~= "table" then
            CellDB["offensives"] = {["disabled"] = {}, ["custom"] = {}}
        end

        local index = Cell.defaults.indicatorIndices.offensiveCooldowns
        local default = Cell.defaults.layout["indicators"][index]
        if default then
            for _, layout in pairs(CellDB["layouts"]) do
                local indicators = layout["indicators"]
                if indicators and (not indicators[index] or indicators[index]["indicatorName"] ~= "offensiveCooldowns") then
                    if #indicators + 1 < index then
                        indicators[#indicators + 1] = F.Copy(default)
                    else
                        tinsert(indicators, index, F.Copy(default))
                    end
                end
            end
        end
    end

    if not(CellDB["revise"]) or dbRevision < 288 then
        local defaults = I.GetDefaultHealerSpells and I.GetDefaultHealerSpells()
        if type(defaults) == "table" then
            for _, layout in pairs(CellDB["layouts"]) do
                for _, t in pairs(layout["indicators"] or {}) do
                    if t["name"] == "Healers" and t["auraType"] == "buff"
                        and (t["type"] == "icons" or t["type"] == "icon")
                        and type(t["auras"]) == "table" then
                        local have = {}
                        for _, id in pairs(t["auras"]) do have[id] = true end
                        for _, id in ipairs(defaults) do
                            if not have[id] then
                                have[id] = true
                                tinsert(t["auras"], id)
                            end
                        end
                    end
                end
            end
        end
    end

    if not(CellDB["revise"]) or dbRevision < 292 then
        if type(CellDB["actions"]) == "table" then
            local topUp = {
                {1295247, {"A", {1, 0.1, 0.1}}},      -- 濃縮版銀月城生命藥水
                {1236648, {"D", {0.2, 0.55, 1}}},     -- 光融法力藥水
                {1263074, {"A", {1, 0.4, 0.4}}},      -- 阿曼尼萃取物
                {1239479, {"D", {0.6, 0.3, 1}}},      -- 吞噬夢境藥水
                {1236590, {"B", {0.3, 1, 0.75}}},     -- 基礎活力藥水
                {1295132, {"C3", {0.3, 0.85, 1}}},    -- 流光藥劑
                {1236998, {"C3", {0.6, 0.2667, 1}}},  -- 猛烈捨棄藥劑
                {1262857, {"A", {1, 0.1, 0.1}}},      -- 強效治療藥水
                {1236994, {"C3", {0.85, 0.35, 1}}},   -- 魯莽藥水
            }

            local seen = {}
            for _, t in pairs(CellDB["actions"]) do
                if type(t) == "table" then seen[t[1]] = true end
            end

            for _, t in ipairs(topUp) do
                if not seen[t[1]] then
                    seen[t[1]] = true
                    tinsert(CellDB["actions"], F.Copy(t))
                end
            end

            -- Revise runs after Core.lua has already built Cell.vars.actions, so rebuild it
            Cell.vars.actions = I.ConvertActions(CellDB["actions"])
        end
    end

    local ANIMATED_INDICATORS = {
        externalCooldowns = true, defensiveCooldowns = true, offensiveCooldowns = true,
        allCooldowns = true, debuffs = true, raidDebuffs = true, crowdControls = true,
    }
    for _, layout in pairs(CellDB["layouts"] or {}) do
        for _, i in pairs(layout["indicators"] or {}) do
            if ANIMATED_INDICATORS[i.indicatorName] or i.type == "icon" or i.type == "icons" then
                if type(i.animationStyle) ~= "string" then
                    i.animationStyle = (i.showAnimation == false) and "none" or "border"
                end
            elseif i.animationStyle ~= nil then
                i.animationStyle = nil
            end
        end
    end

    if not CellDB["miliuiAnimationStyleSplit"] then
        CellDB["miliuiAnimationStyleSplit"] = true
        for _, layout in pairs(CellDB["layouts"] or {}) do
            for _, i in pairs(layout["indicators"] or {}) do
                if i.animationStyle == "clock" then
                    i.animationStyle = "border"
                end
            end
        end
    end

    if not CellDB["miliuiAoEHealingRemoved"] then
        CellDB["miliuiAoEHealingRemoved"] = true
        for _, layout in pairs(CellDB["layouts"] or {}) do
            local indicators = layout["indicators"]
            if type(indicators) == "table" then
                for i = #indicators, 1, -1 do
                    if type(indicators[i]) == "table" and indicators[i]["indicatorName"] == "aoeHealing" then
                        tremove(indicators, i)
                    end
                end
            end
        end
        CellDB["aoeHealings"] = nil
    end

    if not CellDB["miliuiLeftCooldownAnchorReverted"] then
        CellDB["miliuiLeftCooldownAnchorReverted"] = true
        CellDB["miliuiLeftCooldownAnchor"] = nil
        local LEFT_ROWS = { defensiveCooldowns = true, allCooldowns = true }
        for _, layout in pairs(CellDB["layouts"] or {}) do
            for _, t in pairs(layout["indicators"] or {}) do
                if type(t) == "table" and LEFT_ROWS[t["indicatorName"]] then
                    local p = t["position"]
                    if type(p) == "table" and p[1] == "RIGHT" and p[2] == "button" and p[3] == "LEFT" and p[4] == -2 then
                        p[1] = "LEFT"
                        if t["orientation"] == "right-to-left" then
                            t["orientation"] = "left-to-right"
                        end
                    end
                end
            end
        end
    end

    if not CellDB["miliuiHealersNameKey"] then
        CellDB["miliuiHealersNameKey"] = true
        for _, layout in pairs(CellDB["layouts"] or {}) do
            for _, t in pairs(layout["indicators"] or {}) do
                if type(t) == "table" and t["type"] ~= "built-in" and t["name"] == "Healers"
                    and t["nameKey"] == nil then
                    t["nameKey"] = "Healers"
                end
            end
        end
    end

    if not CellDB["miliuiIconsSpacingDefault"] then
        CellDB["miliuiIconsSpacingDefault"] = true
        for _, layout in pairs(CellDB["layouts"] or {}) do
            for _, t in pairs(layout["indicators"] or {}) do
                if type(t) == "table" and t["type"] == "icons" and t["auraType"] == "buff" then
                    local sp = t["spacing"]
                    if type(sp) == "table" and sp[1] == 0 and sp[2] == 0 then
                        t["spacing"] = {2, 2}
                    end
                end
            end
        end
    end

    CellDB["revise"] = Cell.version
    if CellCharacterDB then
        CellCharacterDB["revise"] = Cell.version
    end
end