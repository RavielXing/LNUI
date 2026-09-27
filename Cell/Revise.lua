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

            -- reset layoutAutoSwitch
            -- if not CellDB["layoutAutoSwitch"] then
            --     CellDB["layoutAutoSwitch"] = {}
            -- end
            -- if not CellDB["layoutAutoSwitch"]["role"] then
            --     CellDB["layoutAutoSwitch"]["role"] = {
            --         ["TANK"] = F.Copy(Cell.defaults.layoutAutoSwitch),
            --         ["HEALER"] = F.Copy(Cell.defaults.layoutAutoSwitch),
            --         ["DAMAGER"] = F.Copy(Cell.defaults.layoutAutoSwitch),
            --     }
            -- end
            -- if not CellDB["layoutAutoSwitch"][Cell.vars.playerClass] then
            --     CellDB["layoutAutoSwitch"][Cell.vars.playerClass] = {}
            -- end

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

    --! 12.1: the debuff row is AuraContainer-backed and its "size-normal-big" setting became
    --! a plain size (a container group has one element size). Shape fix only, and it is
    --! self-limiting -- it fires only while the old nested table is still there -- so it can
    --! stay ungated.
    for _, layout in pairs(CellDB["layouts"]) do
        for _, t in pairs(layout["indicators"] or {}) do
            if t["indicatorName"] == "debuffs" and type(t["size"]) == "table" and type(t["size"][1]) == "table" then
                t["size"] = {t["size"][1][1], t["size"][1][2]}
                t["bigDebuffs"] = nil
                t["enableBlacklistShortcut"] = nil
            end
        end
    end

    --! ...and the duration threshold: it works again on the container path, so rows whose
    --! lists carry permanent or very long buffs ("always" printing 28m forever) were moved
    --! from "always" to "under 60s".
    --!
    --! ⚠ ONE-SHOT. This used to run on every login, which meant the conversion was not a
    --! conversion at all -- it was a lock: anyone who chose "always" on the Healers row (or
    --! the debuff rows) got it silently reset to 60s at the next reload, forever, with no
    --! error and nothing in the UI to explain it. A preference the user can set and the
    --! addon un-sets behind their back is worse than the wrong default it was fixing.
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

    --! 12.1: "Raid Debuffs" became "Important Debuffs". It no longer matches a curated
    --! spell-ID list -- it asks Blizzard for five categories (boss/role, priority, crowd
    --! control, raid-wide, dispellable), each its own AuraGroup -- so the old name described
    --! the wrong thing. Seed the toggles too: absent already means ON everywhere that reads
    --! them, this just makes them visible in the options panel.
    --!
    --! ⚠ Revision-gated, unlike the block above. It rewrites sizes and font sizes, and an
    --! ungated version would stomp them back on every single login -- the user could never
    --! change them again.
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

    --! 12.1: the debuff row can now subtract whatever the Important Debuffs display claims,
    --! so the same aura is never drawn twice. Default ON -- but for a layout saved before the
    --! option existed, "key absent" meant the OLD behaviour (show everything), so leaving it
    --! to the absent-means-default rule would silently reinterpret their display. Turn it on
    --! once, explicitly, and let them turn it back off if they disagree.
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

    --! Midnight retired TWW's healing/burst potions, so the stock Actions indicator was
    --! watching two cast IDs that can no longer fire -- silently, since a dead ID looks
    --! exactly like "nobody drank anything". Remap in place: same slot, same animation, same
    --! colour, so anyone who recoloured their potion entries keeps that. A user who already
    --! replaced the ID by hand has no old ID to match and is left alone.
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

    --! New built-in: Offensive Cooldowns. It goes on the END of every layout's indicator list,
    --! never in the middle -- the indices in Cell.defaults.indicatorIndices ARE array positions,
    --! so an insert would silently repoint every indicator after it in every saved layout.
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
                    -- tinsert errors on a position past #t+1, and a layout that skipped an
                    -- earlier migration can be short. Append in that case; the index only has
                    -- to be right for layouts that are actually up to date.
                    if #indicators + 1 < index then
                        indicators[#indicators + 1] = F.Copy(default)
                    else
                        tinsert(indicators, index, F.Copy(default))
                    end
                end
            end
        end
    end

    --! Healer HoT list top-up. F.FirstRun only fires once, so new entries in the default list
    --! never reach anyone who already owns a "Healers" indicator -- which is everyone who has
    --! run Cell before. Append-only and deduped: a spell the user deliberately deleted comes
    --! back once, but nothing they added is touched and no ordering is disturbed.
    --!
    --! Two IDs in that list are unverified (139 Renew re-enabled, 388007/388010/388011/388013
    --! seasonal blessings kept) -- see the comments there. To settle either in-game:
    --!     /run print(C_Spell.GetSpellInfo(139) and "live" or "gone")
    --! A dead ID is inert here, so being wrong costs nothing but a line in the table.
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

    --! Midnight consumables top-up for the Actions indicator. Each of these is its own cast id,
    --! not another rank of one already in the list -- crafting quality shares a cast id, a
    --! different potion NAME does not. 1295247 in particular is the concentrated tier of the
    --! Silvermoon potion and is NOT 1234768, so a list holding only 1234768 stays dark when
    --! someone drinks it.
    --!
    --! Defaults only reach a fresh DB -- Core.lua fills CellDB["actions"] just when the key is
    --! missing, and it is never missing for anyone who has run Cell before -- so top up the
    --! saved list in place. Append-only and deduped by cast id: an entry the user recoloured
    --! or reordered is left exactly as it is, and only ids absent from the list get added.
    --! Same trade as the r288 healer top-up: an id the user deliberately deleted comes back
    --! once. Keep this in sync with I.GetDefaultActions().
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

    --! fix from MiliUI: per-indicator cooldown animation style.
    --! No version gate on purpose -- it only writes a key that is absent, so re-running it
    --! can never overwrite a choice the player made (see the r281/r282 gates, which DID
    --! need one because they rewrote existing values).
    --! Resolved from the old showAnimation boolean so nobody's frames change look on
    --! upgrade: an indicator that was animating keeps the sweep it already had.
    --!
    --! ⚠ ONLY the indicators that actually own the option. The first cut of this wrote the
    --! key onto every entry in the layout, and the apply path then called ShowAnimation on
    --! things like nameText, which has no such method -- "attempt to call a nil value" on
    --! every unit button. The call sites are guarded now too, but a Name Text carrying an
    --! animation style is still nonsense, so stale ones get cleared here.
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

    --! fix from MiliUI: Important Debuffs' two corner marks -- the boss "!" (首領技能驚嘆號) and
    --! the dispel "+" (可驅散加號) -- are on for every layout that predates them, and for old
    --! layouts imported later (they pick them up at the next login).
    --! No version gate: it only fills an ABSENT key, so a player's own "off" is never touched.
    --! Absent is read as OFF everywhere (ConfigureContainer, the options checkbox, the
    --! preview), so the frames and the panel agree even before this has run.
    for _, layout in pairs(CellDB["layouts"] or {}) do
        for _, t in pairs(layout["indicators"] or {}) do
            if type(t) == "table" and t["indicatorName"] == "raidDebuffs" then
                if t["bossBadge"] == nil then t["bossBadge"] = true end
                if t["dispelBadge"] == nil then t["dispelBadge"] = true end
            end
        end
    end

    --! fix from MiliUI: "clock" used to mean what is now "border" -- the animation was a
    --! single style whose sweep happens to land on the ring, and splitting the real clock
    --! sweep out of it left the old value pointing at the wrong look. Rename it once.
    --!
    --! ⚠ Guarded by a ONE-SHOT MARKER, not by dbRevision: a revision gate would need Cell's
    --! TOC "## Version" bumped, and that number is a release signal the user owns -- see
    --! .claude/notes. Without the marker this would keep dragging a deliberate "clock" back
    --! to "border" on every login.
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

    --! fix from MiliUI: the AoE Healing indicator is GONE. It only ever lit up from
    --! COMBAT_LOG_EVENT_UNFILTERED (SPELL_HEAL / SPELL_PERIODIC_HEAL), which addons cannot
    --! register on 12.x -- the option was there but the texture could never flash.
    --!
    --! ⚠ Its slot has to leave the saved layouts as well: Cell.defaults.indicatorIndices IS
    --! the position map into layout["indicators"], so a stale entry left at 17 pushes every
    --! later built-in one slot out of line, and the config loop would then try to create an
    --! indicator that no longer exists (b.indicators.aoeHealing is nil -> I.CreateIndicator
    --! on a "built-in" entry -> indexing a nil). The validation pass above re-indexes by name
    --! and would drop it, but that whole block only runs when CellDB["revise"] differs from
    --! the TOC version -- and that number is a release signal the user owns (see .claude
    --! notes), so it cannot be relied on here. One-shot marker instead.
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

    --! fix from MiliUI: undo "miliuiLeftCooldownAnchor" (2026-08-24). That pass re-pinned the
    --! two left-side cooldown rows (Defensive Cooldowns, Externals + Defensives) from
    --! LEFT/LEFT to RIGHT/LEFT, assuming they hung off the side of the frame. They don't: the
    --! stock -2 puts the row INSIDE the frame, and LEFT/LEFT was already the stable pin. The
    --! re-pin threw every default row outside, onto the neighbouring cell, and clamped any
    --! x below -2 to -2.
    --! ⚠ Only the exact result of that pass is reverted (RIGHT/button/LEFT with x == -2). An x
    --! the player moved afterwards is their own fix and stays. Clamped values are gone for good.
    --! ⚠ One-shot marker, same reason as above: dbRevision needs the TOC version bumped.
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

    --! fix from MiliUI: the "Healers" row Cell offers to create is localized now, and it is
    --! localized through a KEY (see I.GetIndicatorName) rather than by writing a translated
    --! string into the layout -- a stored translation would freeze the row in whatever
    --! language the client happened to be, and an exported profile would carry that language
    --! into everyone else's UI. Tag the rows that already exist with the same key.
    --!
    --! ⚠ Only the untouched default string is tagged. A name the player typed is theirs, and
    --! custom names are free text: matching anything looser would relabel real user data.
    --! ⚠ One-shot marker, not dbRevision: that gate needs the TOC "## Version" bumped, and
    --! that number is a release signal the user owns.
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

    --! fix from MiliUI: custom BUFF icons rows used to ignore their spacing setting in game --
    --! the AuraContainer drew a hard-coded 2px gap no matter what was saved. r302 made the
    --! setting work, and the untouched default {0, 0} would suddenly glue every existing row
    --! together. Rows still on that default move to {2, 2}, i.e. exactly what they looked like.
    --!
    --! ⚠ BUFF only: a DEBUFF icons row never went through the container, so its 0 was always a
    --!   real 0 on screen and changing it would move icons the player already sees.
    --! ⚠ Exactly {0, 0} only: any other value is a choice the player made.
    --! ⚠ One-shot marker, not dbRevision: that gate needs the TOC "## Version" bumped, and
    --!   that number is a release signal the user owns. A layout imported later from an old
    --!   export keeps {0, 0} -- the marker is already set by then.
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